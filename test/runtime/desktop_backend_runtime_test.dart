import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sub_dock/runtime/backend_runtime.dart';
import 'package:sub_dock/runtime/desktop_backend_runtime.dart';
import 'package:sub_dock/runtime/runtime_directories.dart';

void main() {
  group('DesktopBackendRuntime', () {
    late Directory temp;
    late DesktopBackendRuntime runtime;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('sub_dock_runtime_');
      runtime = await _createRuntime(temp, bundledNodeVersion: '24.15.0');
    });

    tearDown(() async {
      await runtime.dispose();
      await temp.delete(recursive: true);
    });

    test('starts once, streams logs, reports info, and stops', () async {
      final logs = <RuntimeLog>[];
      final states = <RuntimeState>[];
      final logSubscription = runtime.logs.listen(logs.add);
      final stateSubscription = runtime.state.listen(states.add);
      addTearDown(logSubscription.cancel);
      addTearDown(stateSubscription.cancel);

      await runtime.start();
      await runtime.start();

      expect(await runtime.isHealthy(), isTrue);
      expect((await runtime.info()).backendVersion, 'fixture-backend');
      expect(
        states.where((state) => state.status == RuntimeStatus.starting),
        hasLength(1),
      );
      await _waitFor(() => logs.length >= 2);
      expect(
        logs.map((log) => log.source),
        containsAll(<RuntimeLogSource>[
          RuntimeLogSource.stdout,
          RuntimeLogSource.stderr,
        ]),
      );
      final logFile = File.fromUri(
        temp.uri.resolve('application-support/logs/backend.log'),
      );
      await _waitFor(
        () =>
            logFile.existsSync() &&
            logFile.readAsStringSync().contains('fixture stdout'),
      );

      await runtime.stop();

      expect(states.last.status, RuntimeStatus.stopped);
      expect(runtime.currentState.status, RuntimeStatus.stopped);
      expect(runtime.endpoint, Uri.parse('http://127.0.0.1:${runtime.port}'));
    });

    test('reports an unexpected child exit as crashed', () async {
      runtime = await _createRuntime(temp, mode: 'crash');
      final states = <RuntimeState>[];
      final subscription = runtime.state.listen(states.add);
      addTearDown(subscription.cancel);

      await expectLater(runtime.start(), throwsStateError);
      await _waitFor(
        () => states.any((state) => state.status == RuntimeStatus.crashed),
      );

      expect(runtime.currentState.status, RuntimeStatus.crashed);
    });

    test(
      'marks a running process unhealthy when its HTTP endpoint closes',
      () async {
        runtime = await _createRuntime(temp, mode: 'unhealthy');
        final states = <RuntimeState>[];
        final subscription = runtime.state.listen(states.add);
        addTearDown(subscription.cancel);

        await runtime.start();
        await _waitFor(
          () => states.any((state) => state.status == RuntimeStatus.unhealthy),
        );

        expect(await runtime.isHealthy(), isFalse);
      },
    );

    test('uses the packaged Node runtime', () async {
      runtime = await _createRuntime(
        temp,
        manifestVersion: '25.0.0',
        bundledNodeVersion: '25.0.0',
      );

      await runtime.start();

      expect(await runtime.isHealthy(), isTrue);
      expect(
        await File.fromUri(temp.uri.resolve('bundle/data/runtime/selected'))
            .exists(),
        isTrue,
      );
    });

    test('rejects a port held by an unknown process', () async {
      final blockedPort = await _unusedPort();
      final blocker = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        blockedPort,
      );
      addTearDown(blocker.close);
      runtime = await _createRuntime(temp, port: blockedPort);

      await expectLater(runtime.start(), throwsStateError);

      expect(runtime.currentState.status, RuntimeStatus.crashed);
    });

    test('rejects a missing manifest external binary', () async {
      runtime = await _createRuntime(
        temp,
        externalBinaries: const <String>['shoutrrr'],
        bundledNodeVersion: '24.15.0',
      );

      await expectLater(runtime.start(), throwsStateError);

      expect(runtime.currentState.status, RuntimeStatus.crashed);
    });

    test('disposes lifecycle resources', () async {
      var stateDone = false;
      final subscription = runtime.state.listen(
        null,
        onDone: () => stateDone = true,
      );
      addTearDown(subscription.cancel);

      await runtime.dispose();
      await _waitFor(() => stateDone);

      expect(stateDone, isTrue);
    });

    test('restarts a healthy backend', () async {
      final states = <RuntimeState>[];
      final subscription = runtime.state.listen(states.add);
      addTearDown(subscription.cancel);

      await runtime.start();
      await runtime.restart();

      expect(await runtime.isHealthy(), isTrue);
      expect(
        states.where((state) => state.status == RuntimeStatus.starting),
        hasLength(2),
      );
    });

    test('times out when an HTTP response never completes', () async {
      runtime = await _createRuntime(temp, mode: 'stall');
      final states = <RuntimeState>[];
      final subscription = runtime.state.listen(states.add);
      addTearDown(subscription.cancel);

      await expectLater(
        runtime.start().timeout(const Duration(seconds: 15)),
        throwsStateError,
      );

      expect(states.last.status, RuntimeStatus.crashed);
    });
  });
}

Future<DesktopBackendRuntime> _createRuntime(
  Directory temp, {
  String mode = 'healthy',
  String manifestVersion = '24.15.0',
  String? bundledNodeVersion = '24.15.0',
  List<String> externalBinaries = const <String>[],
  int? port,
}) async {
  final bundle = Directory.fromUri(temp.uri.resolve('bundle/'));
  final backend = Directory.fromUri(bundle.uri.resolve('data/backend/'));
  await backend.create(recursive: true);
  final fixture = File('test/fixtures/backend_fixture.js');
  var source = await fixture.readAsString();
  source = source.replaceFirst(
    "const mode = process.env.TEST_BACKEND_MODE || 'healthy';",
    "const mode = '$mode';",
  );
  await File.fromUri(backend.uri.resolve('sub-store.bundle.js'))
      .writeAsString(source);
  await File.fromUri(
    backend.uri.resolve('runtime-manifest.json'),
  ).writeAsString(
    '{"testedNode":"$manifestVersion","externalBinary":${jsonEncode(externalBinaries)}}',
  );
  if (bundledNodeVersion != null) {
    final node = File.fromUri(bundle.uri.resolve('data/runtime/node'));
    await node.parent.create(recursive: true);
    await node.writeAsString(
      '#!/bin/sh\nif [ "\$1" = "--version" ]; then echo v$bundledNodeVersion; exit 0; fi\ntouch "${node.parent.path}/selected"\nexec node "\$@"\n',
    );
    await Process.run('chmod', <String>['755', node.path]);
  }
  return DesktopBackendRuntime(
    directories: await RuntimeDirectories.fromBaseDirectory(
      Directory.fromUri(temp.uri.resolve('application-support/')),
    ),
    bundleDirectory: bundle,
    port: port ?? await _unusedPort(),
  );
}

Future<int> _unusedPort() async {
  final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = server.port;
  await server.close();
  return port;
}

Future<void> _waitFor(bool Function() condition) async {
  final timeout = Stopwatch()..start();
  while (!condition()) {
    if (timeout.elapsed > const Duration(seconds: 5)) {
      throw TimeoutException('Condition was not met');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}
