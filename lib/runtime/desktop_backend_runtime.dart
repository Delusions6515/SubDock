import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'backend_runtime.dart';
import 'runtime_directories.dart';

class DesktopRuntimeProfile {
  const DesktopRuntimeProfile._(this.executableSuffix);

  factory DesktopRuntimeProfile.current() =>
      DesktopRuntimeProfile._(Platform.isWindows ? '.exe' : '');

  final String executableSuffix;

  String get nodeFileName => 'node$executableSuffix';

  String externalBinaryFileName(String name) => '$name$executableSuffix';
}

class DesktopBackendRuntime implements BackendRuntime {
  DesktopBackendRuntime({
    required this.directories,
    Directory? bundleDirectory,
    DesktopRuntimeProfile? profile,
    this.port = 3001,
  }) : _bundleDirectory =
           bundleDirectory ?? File(Platform.resolvedExecutable).parent,
       _profile = profile ?? DesktopRuntimeProfile.current();

  static const _healthCheckInterval = Duration(seconds: 1);
  static const _healthCheckTimeout = Duration(seconds: 10);
  static const _httpRequestTimeout = Duration(seconds: 1);
  static const _stopTimeout = Duration(seconds: 5);
  static final _binaryName = RegExp(r'^[A-Za-z0-9._-]+$');

  final RuntimeDirectories directories;
  final Directory _bundleDirectory;
  final DesktopRuntimeProfile _profile;
  final int port;
  final _logs = StreamController<RuntimeLog>.broadcast(sync: true);
  final _states = StreamController<RuntimeState>.broadcast(sync: true);

  RuntimeState _currentState = RuntimeState(
    status: RuntimeStatus.stopped,
    changedAt: DateTime.now(),
  );
  Future<void> _operation = Future<void>.value();
  Process? _process;
  HttpClient? _httpClient;
  IOSink? _logSink;
  Timer? _healthTimer;
  bool _stopping = false;
  bool _checkingHealth = false;
  bool _disposed = false;

  @override
  RuntimeState get currentState => _currentState;

  @override
  Uri get endpoint => Uri(
    scheme: 'http',
    host: InternetAddress.loopbackIPv4.address,
    port: port,
  );

  @override
  Stream<RuntimeLog> get logs => _logs.stream;

  @override
  Stream<RuntimeState> get state => Stream<RuntimeState>.multi((controller) {
    controller.add(_currentState);
    final subscription = _states.stream.listen(
      controller.add,
      onError: controller.addError,
      onDone: controller.close,
    );
    controller.onCancel = subscription.cancel;
  }, isBroadcast: true);

  @override
  Future<void> start() => _serialize(() async {
    _ensureActive();
    await _start();
  });

  @override
  Future<void> stop() => _serialize(() async {
    _ensureActive();
    await _stop();
  });

  @override
  Future<void> restart() => _serialize(() async {
    _ensureActive();
    await _stop();
    await _start();
  });

  @override
  Future<bool> isHealthy() async {
    _ensureActive();
    return _process != null && await _requestInfo() != null;
  }

  @override
  Future<BackendInfo> info() async {
    _ensureActive();
    if (_process == null) throw StateError('Backend is not running');
    final info = await _requestInfo();
    if (info == null) {
      throw StateError('Backend API is unavailable at $endpoint');
    }
    return info;
  }

  @override
  Future<void> dispose() {
    if (_disposed) return Future<void>.value();
    final next = _operation.then((_) => _dispose());
    _operation = next.catchError((Object _) {});
    return next;
  }

  Future<void> _serialize(Future<void> Function() operation) {
    final next = _operation.then((_) => operation());
    _operation = next.catchError((Object _) {});
    return next;
  }

  Future<void> _start() async {
    if (_process != null) {
      if (_currentState.status == RuntimeStatus.running) return;
      throw StateError('Backend process is already active');
    }

    _stopping = false;
    _emit(RuntimeStatus.starting);
    try {
      await _verifyPortAvailable();
      final manifest = await _readRuntimeManifest();
      final node = await _resolveNode(manifest.testedNode);
      await _verifyExternalBinaries(manifest.externalBinaries);
      final bundle = _backendBundle;
      if (!await bundle.exists()) {
        throw StateError('Backend bundle is missing: ${bundle.path}');
      }
      _logSink = File.fromUri(directories.logs.uri.resolve('backend.log'))
          .openWrite(mode: FileMode.append);

      final process = await Process.start(node, [
        bundle.path,
      ], environment: _environment());
      _process = process;
      _capture(process.stdout, RuntimeLogSource.stdout);
      _capture(process.stderr, RuntimeLogSource.stderr);
      unawaited(process.exitCode.then((code) => _handleExit(process, code)));

      if (!await _waitForHealthy(process)) {
        if (identical(_process, process)) {
          await _terminate(process);
          _process = null;
        }
        throw StateError('Backend did not become healthy');
      }

      if (!identical(_process, process)) {
        throw StateError('Backend exited during startup');
      }
      _emit(RuntimeStatus.running);
      _startHealthMonitor();
    } catch (error, stackTrace) {
      final process = _process;
      if (process != null) {
        try {
          await _terminate(process);
        } on Object {
          // The failure below is the startup error that callers can act on.
        }
        if (identical(_process, process)) _process = null;
      }
      _closeHttpClient();
      await _closeLogSink();
      _emit(RuntimeStatus.crashed, '$error');
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> _stop() async {
    _healthTimer?.cancel();
    _healthTimer = null;
    final process = _process;
    if (process == null) {
      _closeHttpClient();
      await _closeLogSink();
      if (_currentState.status != RuntimeStatus.stopped) {
        _emit(RuntimeStatus.stopped);
      }
      return;
    }

    _stopping = true;
    _emit(RuntimeStatus.stopping);
    try {
      await _terminate(process);
      _closeHttpClient();
      await _closeLogSink();
      if (identical(_process, process)) {
        _process = null;
        _emit(RuntimeStatus.stopped);
      }
    } catch (error, stackTrace) {
      _stopping = false;
      _emit(RuntimeStatus.crashed, 'Unable to stop backend: $error');
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> _dispose() async {
    Object? failure;
    StackTrace? failureStackTrace;
    try {
      await _stop();
    } catch (error, stackTrace) {
      failure = error;
      failureStackTrace = stackTrace;
    }
    _healthTimer?.cancel();
    _healthTimer = null;
    _closeHttpClient();
    await _closeLogSink();
    _disposed = true;
    await Future.wait(<Future<void>>[_logs.close(), _states.close()]);
    if (failure != null) {
      Error.throwWithStackTrace(failure, failureStackTrace!);
    }
  }

  Future<void> _verifyPortAvailable() async {
    ServerSocket? socket;
    try {
      socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
    } on SocketException {
      throw StateError('Backend port $port is occupied by an unknown process');
    } finally {
      await socket?.close();
    }
  }

  Future<void> _terminate(Process process) async {
    if (!process.kill()) {
      throw StateError('Backend process could not be terminated');
    }
    try {
      await process.exitCode.timeout(_stopTimeout);
    } on TimeoutException {
      final killed = Platform.isWindows
          ? process.kill()
          : process.kill(ProcessSignal.sigkill);
      if (!killed) {
        throw StateError('Backend process could not be force-terminated');
      }
      await process.exitCode.timeout(_stopTimeout);
    }
  }

  Future<_RuntimeManifest> _readRuntimeManifest() async {
    final manifest = _runtimeManifest;
    if (!await manifest.exists()) {
      throw StateError('Runtime manifest is missing: ${manifest.path}');
    }
    final decoded = jsonDecode(await manifest.readAsString());
    if (decoded is! Map<String, dynamic> || decoded['testedNode'] is! String) {
      throw StateError('Runtime manifest has no testedNode version');
    }
    final binaries = decoded['externalBinary'] ?? const <Object>[];
    if (binaries is! List || binaries.any((item) => item is! String)) {
      throw StateError('Runtime manifest has invalid external binaries');
    }
    return _RuntimeManifest(
      testedNode: decoded['testedNode'] as String,
      externalBinaries: binaries.cast<String>(),
    );
  }

  Future<String> _resolveNode(String testedNode) async {
    final expectedMajor = _majorVersion(testedNode);
    if (expectedMajor == null) {
      throw StateError('Runtime manifest has an invalid testedNode version');
    }
    final node = _runtimeNode;
    if (!await node.exists()) {
      throw StateError('Packaged Node.js runtime is missing: ${node.path}');
    }
    if (!await _hasMajorVersion(node.path, expectedMajor)) {
      throw StateError('Packaged Node.js is not major version $expectedMajor');
    }
    return node.path;
  }

  Future<void> _verifyExternalBinaries(List<String> binaries) async {
    for (final binary in binaries) {
      if (!_binaryName.hasMatch(binary)) {
        throw StateError(
          'Runtime manifest has an invalid binary name: $binary',
        );
      }
      final file = File.fromUri(
        _bundleDirectory.uri.resolve(
          'data/runtime/bin/${_profile.externalBinaryFileName(binary)}',
        ),
      );
      if (!await file.exists()) {
        throw StateError('Packaged external binary is missing: ${file.path}');
      }
      if (!Platform.isWindows && ((await file.stat()).mode & 0x49) == 0) {
        throw StateError(
          'Packaged external binary is not executable: ${file.path}',
        );
      }
    }
  }

  Future<bool> _hasMajorVersion(String executable, int expectedMajor) async {
    try {
      final result = await Process.run(executable, ['--version']);
      if (result.exitCode != 0) return false;
      return _majorVersion(result.stdout.toString().trim()) == expectedMajor;
    } on ProcessException {
      return false;
    }
  }

  int? _majorVersion(String version) {
    final match = RegExp(r'^v?(\d+)\.').firstMatch(version);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  Future<bool> _waitForHealthy(Process process) async {
    final stopwatch = Stopwatch()..start();
    while (stopwatch.elapsed < _healthCheckTimeout) {
      if (!identical(_process, process)) return false;
      if (await isHealthy()) return true;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return false;
  }

  void _startHealthMonitor() {
    _healthTimer = Timer.periodic(_healthCheckInterval, (_) async {
      if (_checkingHealth || _process == null) return;
      _checkingHealth = true;
      try {
        final healthy = await isHealthy();
        if (!healthy && _currentState.status == RuntimeStatus.running) {
          _emit(RuntimeStatus.unhealthy, 'Backend API is unavailable');
        } else if (healthy && _currentState.status == RuntimeStatus.unhealthy) {
          _emit(RuntimeStatus.running);
        }
      } finally {
        _checkingHealth = false;
      }
    });
  }

  Future<BackendInfo?> _requestInfo() async {
    final client = _httpClient ??= HttpClient()
      ..connectionTimeout = _httpRequestTimeout;
    try {
      return await _requestInfoFrom(client).timeout(_httpRequestTimeout);
    } on TimeoutException {
      _closeHttpClient();
      return null;
    } on HttpException {
      return null;
    } on SocketException {
      return null;
    } on FormatException {
      return null;
    }
  }

  Future<BackendInfo?> _requestInfoFrom(HttpClient client) async {
    final request = await client.getUrl(_apiUrl());
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) return null;
    final body = await utf8.decoder.bind(response).join();
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) return null;
    final data = decoded['data'];
    if (data is! Map<String, dynamic>) return null;
    final meta = data['meta'];
    if (meta is! Map<String, dynamic>) return null;
    final node = meta['node'];
    if (node is! Map<String, dynamic> ||
        node['version'] is! String ||
        data['version'] is! String) {
      return null;
    }
    return BackendInfo(
      nodeVersion: node['version'] as String,
      backendVersion: data['version'] as String,
      port: port,
    );
  }

  void _capture(Stream<List<int>> stream, RuntimeLogSource source) {
    stream.transform(utf8.decoder).transform(const LineSplitter()).listen((
      line,
    ) {
      final log = RuntimeLog(
        timestamp: DateTime.now(),
        source: source,
        message: line,
      );
      if (!_logs.isClosed) _logs.add(log);
      _logSink?.writeln(
        '${log.timestamp.toIso8601String()} [${log.source.name}] ${log.message}',
      );
    });
  }

  void _handleExit(Process process, int exitCode) {
    if (!identical(_process, process)) return;
    _healthTimer?.cancel();
    _healthTimer = null;
    _closeHttpClient();
    unawaited(_closeLogSink());
    _process = null;
    if (_stopping) {
      _emit(RuntimeStatus.stopped);
    } else {
      _emit(RuntimeStatus.crashed, 'Backend exited with code $exitCode');
    }
  }

  void _emit(RuntimeStatus status, [String? message]) {
    _currentState = RuntimeState(
      status: status,
      changedAt: DateTime.now(),
      message: message,
    );
    if (!_states.isClosed) _states.add(_currentState);
  }

  Map<String, String> _environment() {
    final environment = Map<String, String>.of(Platform.environment);
    final pathKey = environment.keys.firstWhere(
      (key) => key.toLowerCase() == 'path',
      orElse: () => 'PATH',
    );
    final originalPath = environment[pathKey] ?? '';
    final binaryPath = _runtimeBin.path;
    environment[pathKey] = originalPath.isEmpty
        ? binaryPath
        : '$binaryPath${Platform.pathSeparator}$originalPath';
    environment.addAll(<String, String>{
      'SUB_STORE_BACKEND_API_HOST': InternetAddress.loopbackIPv4.address,
      'SUB_STORE_BACKEND_API_PORT': '$port',
      'SUB_STORE_DATA_BASE_PATH': directories.data.path,
    });
    return environment;
  }

  Uri _apiUrl() => endpoint.replace(path: 'api/utils/env');

  File get _backendBundle => File.fromUri(
    _bundleDirectory.uri.resolve('data/backend/sub-store.bundle.js'),
  );

  File get _runtimeManifest => File.fromUri(
    _bundleDirectory.uri.resolve('data/backend/runtime-manifest.json'),
  );

  File get _runtimeNode => File.fromUri(
    _bundleDirectory.uri.resolve('data/runtime/${_profile.nodeFileName}'),
  );

  Directory get _runtimeBin =>
      Directory.fromUri(_bundleDirectory.uri.resolve('data/runtime/bin/'));

  void _ensureActive() {
    if (_disposed) throw StateError('Backend runtime has been disposed');
  }

  void _closeHttpClient() {
    _httpClient?.close(force: true);
    _httpClient = null;
  }

  Future<void> _closeLogSink() async {
    final logSink = _logSink;
    _logSink = null;
    if (logSink == null) return;
    try {
      await logSink.close();
    } on FileSystemException {
      // Logging failures must not interrupt backend lifecycle handling.
    }
  }
}

class _RuntimeManifest {
  const _RuntimeManifest({
    required this.testedNode,
    required this.externalBinaries,
  });

  final String testedNode;
  final List<String> externalBinaries;
}
