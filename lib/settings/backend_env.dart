import 'dart:collection';
import 'dart:io';

class BackendEnvIssue {
  const BackendEnvIssue(this.message, {this.line});

  final String message;
  final int? line;
}

class BackendEnvDocument {
  BackendEnvDocument._(this.rawText, Map<String, String> values, this.issues)
    : values = UnmodifiableMapView(values);

  static final _keyPattern = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');

  final String rawText;
  final Map<String, String> values;
  final List<BackendEnvIssue> issues;

  bool get isValid => issues.isEmpty;

  factory BackendEnvDocument.parse(String rawText) {
    final values = <String, String>{};
    final issues = <BackendEnvIssue>[];
    final lines = rawText.split('\n');
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index].endsWith('\r')
          ? lines[index].substring(0, lines[index].length - 1)
          : lines[index];
      if (line.trim().isEmpty || line.trimLeft().startsWith('#')) continue;
      final separator = line.indexOf('=');
      if (separator < 1) {
        issues.add(BackendEnvIssue('缺少 KEY=VALUE', line: index + 1));
        continue;
      }
      final key = line.substring(0, separator);
      if (!_keyPattern.hasMatch(key)) {
        issues.add(BackendEnvIssue('环境变量名无效：$key', line: index + 1));
        continue;
      }
      if (values.containsKey(key)) {
        issues.add(BackendEnvIssue('环境变量重复：$key', line: index + 1));
        continue;
      }
      values[key] = line.substring(separator + 1);
    }
    return BackendEnvDocument._(rawText, values, issues);
  }

  BackendEnvDocument withValue(String key, String value) {
    if (!_keyPattern.hasMatch(key)) throw ArgumentError.value(key, 'key');
    if (value.contains('\n') || value.contains('\r')) {
      throw ArgumentError.value(value, 'value', '环境变量值不能包含换行');
    }
    final lineEnding = rawText.contains('\r\n') ? '\r\n' : '\n';
    final trailingLineEnding = rawText.endsWith('\n');
    final lines = rawText.isEmpty
        ? <String>[]
        : rawText.split(RegExp(r'\r?\n'));
    if (trailingLineEnding) lines.removeLast();

    var replaced = false;
    for (var index = 0; index < lines.length; index++) {
      final separator = lines[index].indexOf('=');
      if (separator > 0 && lines[index].substring(0, separator) == key) {
        lines[index] = '$key=$value';
        replaced = true;
      }
    }
    if (!replaced) lines.add('$key=$value');
    return BackendEnvDocument.parse(
      '${lines.join(lineEnding)}${trailingLineEnding ? lineEnding : ''}',
    );
  }
}

class BackendEnvPolicy {
  static const dataBasePath = 'SUB_STORE_DATA_BASE_PATH';
  static const frontendPath = 'SUB_STORE_FRONTEND_PATH';
  static const host = 'SUB_STORE_BACKEND_API_HOST';
  static const port = 'SUB_STORE_BACKEND_API_PORT';
  static const merge = 'SUB_STORE_BACKEND_MERGE';
  static const frontendBackendPath = 'SUB_STORE_FRONTEND_BACKEND_PATH';
  static const frontendHost = 'SUB_STORE_FRONTEND_HOST';
  static const frontendPort = 'SUB_STORE_FRONTEND_PORT';
  static const corsAllowedOrigins = 'SUB_STORE_CORS_ALLOWED_ORIGINS';
  static const metaFolder = 'META_FOLDER';

  static const reservedKeys = <String>{dataBasePath, frontendPath, metaFolder};

  static List<BackendEnvIssue> validate(BackendEnvDocument document) {
    final issues = [...document.issues];
    for (final key in reservedKeys) {
      if (document.values.containsKey(key)) {
        issues.add(BackendEnvIssue('SubDock 保留环境变量：$key'));
      }
    }
    final configuredPort = document.values[port];
    final parsedPort = configuredPort == null
        ? null
        : int.tryParse(configuredPort);
    if (configuredPort != null &&
        (parsedPort == null || parsedPort < 1 || parsedPort > 65535)) {
      issues.add(const BackendEnvIssue('端口必须在 1 到 65535 之间'));
    }
    final configuredMerge = document.values[merge];
    if (configuredMerge != null &&
        configuredMerge != 'true' &&
        configuredMerge != 'false') {
      issues.add(const BackendEnvIssue('合并模式必须为 true 或 false'));
    }
    final configuredPath = document.values[frontendBackendPath];
    if (configuredPath != null && !configuredPath.startsWith('/')) {
      issues.add(const BackendEnvIssue('Frontend Backend Path 必须以 / 开头'));
    }
    for (final origin in _origins(document.values[corsAllowedOrigins])) {
      final uri = Uri.tryParse(origin);
      if (uri == null ||
          (uri.scheme != 'http' && uri.scheme != 'https') ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty ||
          uri.query.isNotEmpty ||
          uri.fragment.isNotEmpty ||
          (uri.path.isNotEmpty && uri.path != '/')) {
        issues.add(BackendEnvIssue('CORS origin 无效：$origin'));
      }
    }
    return issues;
  }

  static Uri localOrigin(BackendEnvDocument document) {
    final configuredHost =
        document.values[host] ?? InternetAddress.loopbackIPv4.address;
    final parsedPort = int.tryParse(document.values[port] ?? '');
    final configuredPort =
        parsedPort != null && parsedPort >= 1 && parsedPort <= 65535
        ? parsedPort
        : 3001;
    return Uri(scheme: 'http', host: configuredHost, port: configuredPort);
  }

  static bool isMergeEnabledFor(BackendEnvDocument document) =>
      document.values[merge] != 'false';

  static bool hasNonLoopbackHost(BackendEnvDocument document) {
    final value = document.values[host] ?? InternetAddress.loopbackIPv4.address;
    return value != 'localhost' && value != '::1' && !value.startsWith('127.');
  }

  static List<String> externalOrigins(BackendEnvDocument document) {
    final local = localOrigin(document).origin;
    return _origins(document.values[corsAllowedOrigins])
        .where((origin) => Uri.tryParse(origin)?.origin != local)
        .toList(growable: false);
  }

  static Iterable<String> _origins(String? value) =>
      value
          ?.split(',')
          .map((origin) => origin.trim())
          .where((origin) => origin.isNotEmpty) ??
      const <String>[];
}
