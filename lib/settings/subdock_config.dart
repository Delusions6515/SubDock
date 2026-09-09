import 'dart:collection';
import 'dart:io';

import 'backend_env.dart';

class SubDockConfig {
  const SubDockConfig({
    this.backend = const SubDockBackendConfig(),
    this.httpMeta = const SubDockHttpMetaConfig(),
  });

  static const schemaVersion = 1;

  final SubDockBackendConfig backend;
  final SubDockHttpMetaConfig httpMeta;

  factory SubDockConfig.fromJson(Object? json) {
    final root = _object(json, '根对象');
    _rejectUnknownKeys(root, const {'schemaVersion', 'backend', 'httpMeta'});
    if (root['schemaVersion'] != schemaVersion) {
      throw const FormatException('不支持的 SubDock 配置版本');
    }
    return SubDockConfig(
      backend: SubDockBackendConfig.fromJson(root['backend']),
      httpMeta: SubDockHttpMetaConfig.fromJson(root['httpMeta']),
    );
  }

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'backend': backend.toJson(),
    'httpMeta': httpMeta.toJson(),
  };

  SubDockConfig copyWith({
    SubDockBackendConfig? backend,
    SubDockHttpMetaConfig? httpMeta,
  }) => SubDockConfig(
    backend: backend ?? this.backend,
    httpMeta: httpMeta ?? this.httpMeta,
  );

  @override
  bool operator ==(Object other) =>
      other is SubDockConfig &&
      other.backend == backend &&
      other.httpMeta == httpMeta;

  @override
  int get hashCode => Object.hash(backend, httpMeta);
}

class SubDockBackendConfig {
  const SubDockBackendConfig({
    this.apiHost,
    this.apiPort,
    this.merge,
    this.frontendBackendPath,
    this.corsAllowedOrigins,
  });

  final String? apiHost;
  final int? apiPort;
  final bool? merge;
  final String? frontendBackendPath;
  final String? corsAllowedOrigins;

  factory SubDockBackendConfig.fromJson(Object? json) {
    if (json == null) return const SubDockBackendConfig();
    final object = _object(json, 'backend');
    _rejectUnknownKeys(object, const {
      'apiHost',
      'apiPort',
      'merge',
      'frontendBackendPath',
      'corsAllowedOrigins',
    });
    final config = SubDockBackendConfig(
      apiHost: _optionalString(object, 'apiHost'),
      apiPort: _optionalPort(object, 'apiPort'),
      merge: _optionalBool(object, 'merge'),
      frontendBackendPath: _optionalString(object, 'frontendBackendPath'),
      corsAllowedOrigins: _optionalString(object, 'corsAllowedOrigins'),
    );
    _validateBackend(config);
    return config;
  }

  Map<String, Object?> toJson() => {
    'apiHost': apiHost,
    'apiPort': apiPort,
    'merge': merge,
    'frontendBackendPath': frontendBackendPath,
    'corsAllowedOrigins': corsAllowedOrigins,
  };

  SubDockBackendConfig copyWith({
    Object? apiHost = _unset,
    Object? apiPort = _unset,
    Object? merge = _unset,
    Object? frontendBackendPath = _unset,
    Object? corsAllowedOrigins = _unset,
  }) => SubDockBackendConfig(
    apiHost: identical(apiHost, _unset) ? this.apiHost : apiHost as String?,
    apiPort: identical(apiPort, _unset) ? this.apiPort : apiPort as int?,
    merge: identical(merge, _unset) ? this.merge : merge as bool?,
    frontendBackendPath: identical(frontendBackendPath, _unset)
        ? this.frontendBackendPath
        : frontendBackendPath as String?,
    corsAllowedOrigins: identical(corsAllowedOrigins, _unset)
        ? this.corsAllowedOrigins
        : corsAllowedOrigins as String?,
  );

  @override
  bool operator ==(Object other) =>
      other is SubDockBackendConfig &&
      other.apiHost == apiHost &&
      other.apiPort == apiPort &&
      other.merge == merge &&
      other.frontendBackendPath == frontendBackendPath &&
      other.corsAllowedOrigins == corsAllowedOrigins;

  @override
  int get hashCode => Object.hash(
    apiHost,
    apiPort,
    merge,
    frontendBackendPath,
    corsAllowedOrigins,
  );
}

class SubDockHttpMetaConfig {
  const SubDockHttpMetaConfig({this.enabled = true, this.host, this.port});

  final bool enabled;
  final String? host;
  final int? port;

  factory SubDockHttpMetaConfig.fromJson(Object? json) {
    if (json == null) return const SubDockHttpMetaConfig();
    final object = _object(json, 'httpMeta');
    _rejectUnknownKeys(object, const {'enabled', 'host', 'port'});
    final config = SubDockHttpMetaConfig(
      enabled: _optionalBool(object, 'enabled') ?? true,
      host: _optionalString(object, 'host'),
      port: _optionalPort(object, 'port'),
    );
    if (config.host?.isEmpty ?? false) {
      throw const FormatException('httpMeta.host 不能为空');
    }
    return config;
  }

  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'host': host,
    'port': port,
  };

  SubDockHttpMetaConfig copyWith({
    Object? enabled = _unset,
    Object? host = _unset,
    Object? port = _unset,
  }) => SubDockHttpMetaConfig(
    enabled: identical(enabled, _unset) ? this.enabled : enabled as bool,
    host: identical(host, _unset) ? this.host : host as String?,
    port: identical(port, _unset) ? this.port : port as int?,
  );

  @override
  bool operator ==(Object other) =>
      other is SubDockHttpMetaConfig &&
      other.enabled == enabled &&
      other.host == host &&
      other.port == port;

  @override
  int get hashCode => Object.hash(enabled, host, port);
}

class EffectiveRuntimeConfig {
  const EffectiveRuntimeConfig._({
    required this.environment,
    required this.httpMetaEnabled,
  });

  final Map<String, String> environment;
  final bool httpMetaEnabled;

  factory EffectiveRuntimeConfig.resolve({
    required Map<String, String> systemEnvironment,
    required BackendEnvDocument backendEnvironment,
    required SubDockConfig config,
    Directory? dataDirectory,
    Directory? frontendDirectory,
    Directory? metaFolder,
  }) {
    final environment = Map<String, String>.of(systemEnvironment);
    environment.addAll(backendEnvironment.values);
    _applyBackendOverrides(environment, config.backend);
    environment.putIfAbsent(
      BackendEnvPolicy.host,
      () => InternetAddress.loopbackIPv4.address,
    );
    environment.putIfAbsent(BackendEnvPolicy.port, () => '3001');
    environment.putIfAbsent(BackendEnvPolicy.merge, () => 'true');
    environment.putIfAbsent(BackendEnvPolicy.frontendBackendPath, () => '/');
    environment.putIfAbsent(
      BackendEnvPolicy.corsAllowedOrigins,
      () =>
          'http://${environment[BackendEnvPolicy.host]}:'
          '${environment[BackendEnvPolicy.port]}',
    );
    if (config.httpMeta.host != null) {
      environment['HOST'] = config.httpMeta.host!;
    }
    environment.putIfAbsent('HOST', () => InternetAddress.loopbackIPv4.address);
    if (config.httpMeta.port != null) {
      environment['PORT'] = '${config.httpMeta.port}';
    }
    environment.putIfAbsent('PORT', () => '9876');
    if (dataDirectory != null &&
        frontendDirectory != null &&
        metaFolder != null) {
      environment.addAll({
        BackendEnvPolicy.dataBasePath: dataDirectory.path,
        BackendEnvPolicy.frontendPath: frontendDirectory.path,
        BackendEnvPolicy.metaFolder: metaFolder.path,
        'META_TEMP_FOLDER': Directory.fromUri(
          dataDirectory.uri.resolve('http-meta'),
        ).path,
      });
    }
    return EffectiveRuntimeConfig._(
      environment: UnmodifiableMapView(environment),
      httpMetaEnabled: config.httpMeta.enabled,
    );
  }

  static void _applyBackendOverrides(
    Map<String, String> environment,
    SubDockBackendConfig config,
  ) {
    if (config.apiHost != null) {
      environment[BackendEnvPolicy.host] = config.apiHost!;
    }
    if (config.apiPort != null) {
      environment[BackendEnvPolicy.port] = '${config.apiPort}';
    }
    if (config.merge != null) {
      environment[BackendEnvPolicy.merge] = '${config.merge}';
    }
    if (config.frontendBackendPath != null) {
      environment[BackendEnvPolicy.frontendBackendPath] =
          config.frontendBackendPath!;
    }
    if (config.corsAllowedOrigins != null) {
      environment[BackendEnvPolicy.corsAllowedOrigins] =
          config.corsAllowedOrigins!;
    }
  }
}

Map<String, Object?> _object(Object? value, String name) {
  if (value is! Map) throw FormatException('$name 必须是对象');
  final object = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) throw FormatException('$name 的字段名无效');
    object[entry.key as String] = entry.value;
  }
  return object;
}

void _rejectUnknownKeys(Map<String, Object?> object, Set<String> allowed) {
  final unknown = object.keys.where((key) => !allowed.contains(key));
  if (unknown.isNotEmpty) {
    throw FormatException('不支持的 SubDock 配置字段：${unknown.first}');
  }
}

String? _optionalString(Map<String, Object?> object, String key) {
  final value = object[key];
  if (value == null) return null;
  if (value is! String || value.contains('\n') || value.contains('\r')) {
    throw FormatException('$key 必须是不含换行的字符串');
  }
  return value;
}

bool? _optionalBool(Map<String, Object?> object, String key) {
  final value = object[key];
  if (value == null) return null;
  if (value is! bool) throw FormatException('$key 必须是布尔值');
  return value;
}

int? _optionalPort(Map<String, Object?> object, String key) {
  final value = object[key];
  if (value == null) return null;
  if (value is! int || value < 1 || value > 65535) {
    throw FormatException('$key 必须在 1 到 65535 之间');
  }
  return value;
}

void _validateBackend(SubDockBackendConfig config) {
  if (config.apiHost?.isEmpty ?? false) {
    throw const FormatException('backend.apiHost 不能为空');
  }
  if (config.frontendBackendPath != null &&
      !config.frontendBackendPath!.startsWith('/')) {
    throw const FormatException('backend.frontendBackendPath 必须以 / 开头');
  }
  final origins = config.corsAllowedOrigins;
  if (origins == null) return;
  final issues = BackendEnvPolicy.validate(
    BackendEnvDocument.parse('${BackendEnvPolicy.corsAllowedOrigins}=$origins'),
  );
  if (issues.isNotEmpty) throw FormatException(issues.first.message);
}

const _unset = Object();
