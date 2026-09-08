import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sub_dock/app/app_coordinator.dart';
import 'package:sub_dock/runtime/backend_runtime.dart';
import 'package:sub_dock/runtime/runtime_directories.dart';
import 'package:sub_dock/settings/backend_env.dart';
import 'package:sub_dock/settings/backend_env_store.dart';

void main() {
  test('serializes environment activation before a backend start', () async {
    final temp = await Directory.systemTemp.createTemp('sub_dock_coordinator_');
    addTearDown(() => temp.delete(recursive: true));
    final runtime = _FakeRuntime();
    final coordinator = AppCoordinator(
      runtime: runtime,
      environmentStore: BackendEnvStore(
        await RuntimeDirectories.fromBaseDirectory(temp),
      ),
    );
    final document = BackendEnvDocument.parse(
      'SUB_STORE_BACKEND_API_PORT=3002\n',
    );

    await Future.wait([
      coordinator.saveEnvironment(document),
      coordinator.start(),
    ]);

    expect(runtime.operations, ['environment:3002', 'start']);
    expect(coordinator.webUiUri.path, '/');
    expect(coordinator.webUiUri.queryParameters, isEmpty);
  });

  test('opens a standalone frontend with its proxied API URL', () async {
    final temp = await Directory.systemTemp.createTemp('sub_dock_coordinator_');
    addTearDown(() => temp.delete(recursive: true));
    final coordinator = AppCoordinator(
      runtime: _FakeRuntime(),
      environmentStore: BackendEnvStore(
        await RuntimeDirectories.fromBaseDirectory(temp),
      ),
    );

    await coordinator.saveEnvironment(
      BackendEnvDocument.parse(
        'SUB_STORE_BACKEND_MERGE=false\n'
        'SUB_STORE_FRONTEND_PORT=3100\n'
        'SUB_STORE_FRONTEND_BACKEND_PATH=/subdock\n',
      ),
    );

    expect(coordinator.webUiUri, Uri.parse('http://127.0.0.1:3100/'));
    expect(coordinator.webUiApiUri, Uri.parse('http://127.0.0.1:3100/subdock'));
  });

  test(
    'refuses backend start when update recovery could not complete',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'sub_dock_coordinator_',
      );
      addTearDown(() => temp.delete(recursive: true));
      final runtime = _FakeRuntime();
      final coordinator = AppCoordinator(
        runtime: runtime,
        environmentStore: BackendEnvStore(
          await RuntimeDirectories.fromBaseDirectory(temp),
        ),
        startupBlocker: '组件更新恢复失败',
      );

      await expectLater(coordinator.start(), throwsStateError);

      expect(runtime.operations, isEmpty);
    },
  );
}

class _FakeRuntime implements BackendRuntime {
  final operations = <String>[];
  final _states = StreamController<RuntimeState>.broadcast();
  var port = 3001;

  @override
  RuntimeState get currentState =>
      RuntimeState(status: RuntimeStatus.stopped, changedAt: DateTime.now());

  @override
  Uri get endpoint => Uri.parse('http://127.0.0.1:$port');

  @override
  Stream<RuntimeLog> get logs => const Stream<RuntimeLog>.empty();

  @override
  Stream<RuntimeState> get state => _states.stream;

  @override
  Future<void> activateUserEnvironment(Map<String, String> environment) async {
    port =
        int.tryParse(environment['SUB_STORE_BACKEND_API_PORT'] ?? '') ?? port;
    operations.add('environment:$port');
  }

  @override
  Future<void> dispose() => _states.close();

  @override
  Future<BackendInfo> info() => throw UnimplementedError();

  @override
  Future<bool> isHealthy() async => false;

  @override
  Future<void> restart() async => operations.add('restart');

  @override
  Future<void> start() async => operations.add('start');

  @override
  Future<void> stop() async => operations.add('stop');
}
