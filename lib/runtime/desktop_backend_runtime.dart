import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'backend_runtime.dart';
import 'runtime_directories.dart';

class DesktopBackendRuntime implements BackendRuntime {
  DesktopBackendRuntime({
    required this.directories,
    Directory? bundleDirectory,
    this.port = 3001,
  }) : _bundleDirectory =
           bundleDirectory ?? File(Platform.resolvedExecutable).parent;

  static const _healthCheckInterval = Duration(seconds: 1);
  static const _healthCheckTimeout = Duration(seconds: 10);
  static const _httpRequestTimeout = Duration(seconds: 1);
  static const _stopTimeout = Duration(seconds: 5);

  final RuntimeDirectories directories;
  final Directory _bundleDirectory;
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

  @override
  Stream<RuntimeLog> get logs => _logs.stream;

  @override
  Stream<RuntimeState> get state => _states.stream;

  @override
  Future<void> start() => _serialize(_start);

  @override
  Future<void> stop() => _serialize(_stop);

  @override
  Future<void> restart() => _serialize(() async {
    await _stop();
    await _start();
  });

  @override
  Future<bool> isHealthy() async => await _requestInfo() != null;

  @override
  Future<BackendInfo> info() async {
    final info = await _requestInfo();
    if (info == null) {
      throw StateError('Backend API is unavailable at ${_apiUrl()}');
    }
    return info;
  }

  Future<void> _serialize(Future<void> Function() operation) {
    final next = _operation.then((_) => operation());
    _operation = next.catchError((Object _) {});
    return next;
  }

  Future<void> _start() async {
    if (_process != null ||
        _currentState.status == RuntimeStatus.starting ||
        _currentState.status == RuntimeStatus.running) {
      return;
    }

    _stopping = false;
    _emit(RuntimeStatus.starting);
    try {
      final node = await _resolveNode();
      final bundle = _backendBundle;
      if (!await bundle.exists()) {
        throw StateError('Backend bundle is missing: ${bundle.path}');
      }
      _logSink = File.fromUri(directories.logs.uri.resolve('backend.log'))
          .openWrite(mode: FileMode.append);

      final process = await Process.start(
        node,
        [bundle.path],
        environment: <String, String>{
          ...Platform.environment,
          'SUB_STORE_BACKEND_API_HOST': InternetAddress.loopbackIPv4.address,
          'SUB_STORE_BACKEND_API_PORT': '$port',
          'SUB_STORE_DATA_BASE_PATH': directories.data.path,
        },
      );
      _process = process;
      _capture(process.stdout, RuntimeLogSource.stdout);
      _capture(process.stderr, RuntimeLogSource.stderr);
      unawaited(process.exitCode.then((code) => _handleExit(process, code)));

      if (!await _waitForHealthy(process)) {
        if (identical(_process, process)) {
          await _terminate(process);
          _process = null;
          _emit(RuntimeStatus.crashed, 'Backend did not become healthy');
        }
        return;
      }

      if (!identical(_process, process)) return;
      _emit(RuntimeStatus.running);
      _startHealthMonitor();
    } catch (error) {
      await _closeLogSink();
      _emit(RuntimeStatus.crashed, '$error');
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
    await _terminate(process);
    _closeHttpClient();
    await _closeLogSink();
    if (identical(_process, process)) {
      _process = null;
      _emit(RuntimeStatus.stopped);
    }
  }

  Future<void> _terminate(Process process) async {
    process.kill(ProcessSignal.sigterm);
    try {
      await process.exitCode.timeout(_stopTimeout);
    } on TimeoutException {
      process.kill(ProcessSignal.sigkill);
      await process.exitCode;
    }
  }

  Future<String> _resolveNode() async {
    final manifest = _runtimeManifest;
    if (!await manifest.exists()) {
      throw StateError('Runtime manifest is missing: ${manifest.path}');
    }
    final decoded = jsonDecode(await manifest.readAsString());
    if (decoded is! Map<String, dynamic> || decoded['testedNode'] is! String) {
      throw StateError('Runtime manifest has no testedNode version');
    }
    final expectedMajor = _majorVersion(decoded['testedNode'] as String);
    if (expectedMajor == null) {
      throw StateError('Runtime manifest has an invalid testedNode version');
    }

    if (await _hasMajorVersion('node', expectedMajor)) return 'node';

    final fallback = File.fromUri(
      _bundleDirectory.uri.resolve('data/runtime/linux-x64/bin/node'),
    );
    if (await fallback.exists() &&
        await _hasMajorVersion(fallback.path, expectedMajor)) {
      return fallback.path;
    }
    throw StateError('No Node.js $expectedMajor runtime is available');
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
      _logs.add(log);
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
    _states.add(_currentState);
  }

  Uri _apiUrl() => Uri(
    scheme: 'http',
    host: InternetAddress.loopbackIPv4.address,
    port: port,
    path: 'api/utils/env',
  );

  File get _backendBundle => File.fromUri(
    _bundleDirectory.uri.resolve('data/backend/sub-store.bundle.js'),
  );

  File get _runtimeManifest => File.fromUri(
    _bundleDirectory.uri.resolve('data/backend/runtime-manifest.json'),
  );

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
