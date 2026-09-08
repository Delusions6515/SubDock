import '../runtime/backend_runtime.dart';
import '../settings/backend_env.dart';
import '../settings/backend_env_store.dart';

class AppCoordinator {
  AppCoordinator({
    required this.runtime,
    required this.environmentStore,
    this.startupBlocker,
  });

  final BackendRuntime runtime;
  final BackendEnvStore environmentStore;
  final String? startupBlocker;
  BackendEnvDocument _environment = BackendEnvDocument.parse('');
  Future<void> _operation = Future<void>.value();

  BackendEnvDocument get environment => _environment;

  List<BackendEnvIssue> get environmentIssues =>
      BackendEnvPolicy.validate(_environment);

  bool get canOpenWebUi =>
      environmentIssues.isEmpty &&
      (_environment.values[BackendEnvPolicy.frontendBackendPath] ?? '/')
          .startsWith('/');

  Uri get webUiUri => _frontendOrigin.replace(path: '/');

  Uri get webUiApiUri => _frontendOrigin.replace(
    path: _environment.values[BackendEnvPolicy.frontendBackendPath] ?? '/',
  );

  Uri get _frontendOrigin {
    if (BackendEnvPolicy.isMergeEnabledFor(_environment)) {
      return runtime.endpoint;
    }
    final port = int.tryParse(
      _environment.values[BackendEnvPolicy.frontendPort] ?? '',
    );
    return runtime.endpoint.replace(
      host:
          _environment.values[BackendEnvPolicy.frontendHost] ??
          runtime.endpoint.host,
      port: port != null && port >= 1 && port <= 65535 ? port : 3001,
    );
  }

  Future<void> loadEnvironment() => _serialize(() async {
    final document = await environmentStore.load();
    final issues = BackendEnvPolicy.validate(document);
    if (issues.isNotEmpty) {
      _environment = document;
      throw StateError(issues.first.message);
    }
    await runtime.activateUserEnvironment(document.values);
    _environment = document;
  });

  Future<void> saveEnvironment(BackendEnvDocument document) =>
      _serialize(() async {
        final issues = BackendEnvPolicy.validate(document);
        if (issues.isNotEmpty) throw StateError(issues.first.message);
        await environmentStore.save(document);
        await runtime.activateUserEnvironment(document.values);
        _environment = document;
      });

  Future<void> start() => _serialize(() async {
    _ensureStartupAllowed();
    if (environmentIssues.isNotEmpty) {
      throw StateError(environmentIssues.first.message);
    }
    await runtime.start();
  });

  Future<void> stop() => _serialize(runtime.stop);

  Future<void> restart() => _serialize(() async {
    _ensureStartupAllowed();
    if (environmentIssues.isNotEmpty) {
      throw StateError(environmentIssues.first.message);
    }
    await runtime.restart();
  });

  Future<void> dispose() => _serialize(runtime.dispose);

  Future<void> _serialize(Future<void> Function() action) {
    final next = _operation.then((_) => action());
    _operation = next.catchError((Object _) {});
    return next;
  }

  void _ensureStartupAllowed() {
    if (startupBlocker != null) throw StateError(startupBlocker!);
  }
}
