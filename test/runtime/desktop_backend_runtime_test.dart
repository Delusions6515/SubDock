import 'dart:async';
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
      runtime = await _createRuntime(temp);
    });

    tearDown(() async {
      await runtime.stop();
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
    });

    test('reports an unexpected child exit as crashed', () async {
      runtime = await _createRuntime(temp, mode: 'crash');
      final states = <RuntimeState>[];
      final subscription = runtime.state.listen(states.add);
      addTearDown(subscription.cancel);

      await runtime.start();
      await _waitFor(
        () => states.any((state) => state.status == RuntimeStatus.crashed),
      );

      expect(states.last.status, RuntimeStatus.crashed);
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

    test(
      'uses the bundled Node fallback for a system-version mismatch',
      () async {
        runtime = await _createRuntime(
          temp,
          manifestVersion: '25.0.0',
          bundledNodeVersion: '25.0.0',
        );

        await runtime.start();

        expect(await runtime.isHealthy(), isTrue);
      },
    );
  });
}

Future<DesktopBackendRuntime> _createRuntime(
  Directory temp, {
  String mode = 'healthy',
  String manifestVersion = '24.15.0',
  String? bundledNodeVersion,
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
  await File.fromUri(backend.uri.resolve('runtime-manifest.json'))
      .writeAsString('{"testedNode":"$manifestVersion"}');
  if (bundledNodeVersion != null) {
    final node = File.fromUri(
      bundle.uri.resolve('data/runtime/linux-x64/bin/node'),
    );
    await node.parent.create(recursive: true);
    await node.writeAsString(
      '#!/bin/sh\nif [ "\$1" = "--version" ]; then echo v$bundledNodeVersion; exit 0; fi\nexec node "\$@"\n',
    );
    await Process.run('chmod', <String>['755', node.path]);
  }
  return DesktopBackendRuntime(
    directories: await RuntimeDirectories.fromBaseDirectory(
      Directory.fromUri(temp.uri.resolve('application-support/')),
    ),
    bundleDirectory: bundle,
    port: await _unusedPort(),
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
