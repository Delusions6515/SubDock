import 'dart:collection';
import 'dart:io';

import '../runtime/backend_runtime.dart';
import '../settings/backend_env.dart';
import '../settings/backend_env_store.dart';
import '../settings/subdock_config.dart';
import '../settings/subdock_config_store.dart';
import '../update/component_metadata_store.dart';
import '../update/component_update_checker.dart';
import '../update/component_update_service.dart';

class AppCoordinator {
  AppCoordinator({
    required this.runtime,
    required this.environmentStore,
    this.configurationStore,
    this.startupBlocker,
    this.componentUpdates,
  });

  final BackendRuntime runtime;
  final BackendEnvStore environmentStore;
  final SubDockConfigStore? configurationStore;
  final String? startupBlocker;
  final ComponentUpdateOperations? componentUpdates;
  BackendEnvDocument _environment = BackendEnvDocument.parse('');
  SubDockConfig _configuration = const SubDockConfig();
  String? _configurationError;
  Map<String, String> _effectiveEnvironment = const <String, String>{};
  Future<void> _operation = Future<void>.value();

  BackendEnvDocument get environment => _environment;
  SubDockConfig get configuration => _configuration;
  String? get configurationError => _configurationError;
  Map<String, String> get effectiveEnvironment =>
      UnmodifiableMapView(_effectiveEnvironment);

  List<BackendEnvIssue> get environmentIssues =>
      BackendEnvPolicy.validate(_environment);

  bool get canOpenWebUi =>
      environmentIssues.isEmpty &&
      (_effectiveValue(BackendEnvPolicy.frontendBackendPath) ?? '/').startsWith(
        '/',
      );

  Uri get webUiUri => _frontendOrigin.replace(path: '/');

  Uri get webUiApiUri => _frontendOrigin.replace(
    path: _effectiveValue(BackendEnvPolicy.frontendBackendPath) ?? '/',
  );

  Uri get _frontendOrigin {
    if (_effectiveValue(BackendEnvPolicy.merge) != 'false') {
      return runtime.endpoint;
    }
    final port = int.tryParse(
      _effectiveValue(BackendEnvPolicy.frontendPort) ?? '',
    );
    return runtime.endpoint.replace(
      host:
          _effectiveValue(BackendEnvPolicy.frontendHost) ??
          runtime.endpoint.host,
      port: port != null && port >= 1 && port <= 65535 ? port : 3001,
    );
  }

  Future<void> loadEnvironment() => _serialize(() async {
    final document = await environmentStore.load();
    SubDockConfig configuration;
    try {
      configuration = await _loadConfiguration();
      _configurationError = null;
    } on FormatException catch (error) {
      _configuration = const SubDockConfig();
      _configurationError = error.message;
      throw StateError('SubDock 配置无效：${error.message}');
    }
    final issues = BackendEnvPolicy.validate(document);
    if (issues.isNotEmpty) {
      _environment = document;
      throw StateError(issues.first.message);
    }
    await _activate(document, configuration);
    _environment = document;
    _configuration = configuration;
  });

  Future<void> saveEnvironment(BackendEnvDocument document) =>
      _serialize(() async {
        final issues = BackendEnvPolicy.validate(document);
        if (issues.isNotEmpty) throw StateError(issues.first.message);
        await environmentStore.save(document);
        await _activate(document, _configuration);
        _environment = document;
      });

  Future<void> saveConfiguration(SubDockConfig configuration) =>
      _serialize(() async {
        SubDockConfig.fromJson(configuration.toJson());
        final store = configurationStore;
        if (store == null) throw StateError('SubDock 配置存储尚未启用');
        await store.save(configuration);
        await _activate(_environment, configuration);
        _configuration = configuration;
        _configurationError = null;
      });

  Future<void> resetConfiguration() => _serialize(() async {
    final store = configurationStore;
    if (store == null) throw StateError('SubDock 配置存储尚未启用');
    await store.reset();
    const configuration = SubDockConfig();
    await _activate(_environment, configuration);
    _configuration = configuration;
    _configurationError = null;
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

  Future<ComponentUpdate> checkComponent(ComponentKind kind) =>
      _serializeValue(() => _requireUpdates().check(kind));

  Future<ComponentVersionStatus> componentStatus(ComponentKind kind) =>
      _serializeValue(() => _requireUpdates().status(kind));

  Future<void> updateComponent(ComponentUpdate update) => _serialize(() async {
    _ensureStartupAllowed();
    await _requireUpdates().update(update);
  });

  Future<void> rollbackComponent(ComponentKind kind) => _serialize(() async {
    _ensureStartupAllowed();
    await _requireUpdates().rollback(kind);
  });

  Future<void> _serialize(Future<void> Function() action) {
    final next = _operation.then((_) => action());
    _operation = next.catchError((Object _) {});
    return next;
  }

  Future<T> _serializeValue<T>(Future<T> Function() action) {
    final next = _operation.then((_) => action());
    _operation = next.then<void>((_) {}).catchError((Object _) {});
    return next;
  }

  ComponentUpdateOperations _requireUpdates() {
    final updates = componentUpdates;
    if (updates == null) {
      throw StateError('组件更新器尚未在当前平台启用');
    }
    return updates;
  }

  void _ensureStartupAllowed() {
    if (startupBlocker != null) throw StateError(startupBlocker!);
  }

  Future<SubDockConfig> _loadConfiguration() async {
    final store = configurationStore;
    return store == null ? const SubDockConfig() : store.load();
  }

  Future<void> _activate(
    BackendEnvDocument environment,
    SubDockConfig configuration,
  ) async {
    final effective = EffectiveRuntimeConfig.resolve(
      systemEnvironment: Platform.environment,
      backendEnvironment: environment,
      config: configuration,
    );
    await runtime.activateConfiguration(effective);
    _effectiveEnvironment = effective.environment;
  }

  String? _effectiveValue(String key) =>
      _effectiveEnvironment[key] ?? _environment.values[key];
}
