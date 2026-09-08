import 'dart:async';

abstract class BackendRuntime {
  RuntimeState get currentState;

  Uri get endpoint;

  Future<void> start();

  Future<void> stop();

  Future<void> restart();

  Future<bool> isHealthy();

  Future<BackendInfo> info();

  Future<void> dispose();

  Stream<RuntimeLog> get logs;

  Stream<RuntimeState> get state;
}

enum RuntimeStatus { stopped, starting, running, stopping, unhealthy, crashed }

class RuntimeState {
  const RuntimeState({
    required this.status,
    required this.changedAt,
    this.message,
  });

  final RuntimeStatus status;
  final DateTime changedAt;
  final String? message;
}

enum RuntimeLogSource { stdout, stderr }

class RuntimeLog {
  const RuntimeLog({
    required this.timestamp,
    required this.source,
    required this.message,
  });

  final DateTime timestamp;
  final RuntimeLogSource source;
  final String message;
}

class BackendInfo {
  const BackendInfo({
    required this.nodeVersion,
    required this.backendVersion,
    required this.port,
  });

  final String nodeVersion;
  final String backendVersion;
  final int port;
}
