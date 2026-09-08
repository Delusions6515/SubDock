import 'dart:async';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:sub_dock/app/app.dart';
import 'package:sub_dock/runtime/backend_runtime.dart';

void main() {
  testWidgets('dashboard controls the backend through its abstraction', (
    WidgetTester tester,
  ) async {
    final runtime = _FakeBackendRuntime();
    addTearDown(runtime.dispose);

    await tester.pumpWidget(SubDockApp(runtime: runtime));

    expect(find.text('Stopped'), findsOneWidget);
    expect(find.text('Node Version'), findsOneWidget);
    expect(find.text('Backend Version'), findsOneWidget);
    expect(find.text('Port'), findsOneWidget);

    await tester.tap(find.text('Start'));
    await tester.pump();

    expect(runtime.starts, 1);
    expect(find.text('Running'), findsOneWidget);
    expect(find.text('v24.20.0'), findsOneWidget);
    expect(find.text('fixture-backend'), findsOneWidget);
    expect(find.text('3001'), findsOneWidget);

    await tester.tap(find.text('Stop'));
    await tester.pump();

    expect(runtime.stops, 1);
    expect(find.text('Stopped'), findsOneWidget);
  });

  testWidgets('dashboard stops the runtime when the app detaches', (
    WidgetTester tester,
  ) async {
    final runtime = _FakeBackendRuntime();
    addTearDown(runtime.dispose);

    await tester.pumpWidget(SubDockApp(runtime: runtime));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.detached);
    await tester.pump();

    expect(runtime.stops, 1);
  });
}

class _FakeBackendRuntime implements BackendRuntime {
  final _logs = StreamController<RuntimeLog>.broadcast(sync: true);
  final _states = StreamController<RuntimeState>.broadcast(sync: true);
  var starts = 0;
  var stops = 0;

  @override
  RuntimeState get currentState => RuntimeState(
    status: starts > stops ? RuntimeStatus.running : RuntimeStatus.stopped,
    changedAt: DateTime.now(),
  );

  @override
  Uri get endpoint => Uri.parse('http://127.0.0.1:3001');

  @override
  Stream<RuntimeLog> get logs => _logs.stream;

  @override
  Stream<RuntimeState> get state => _states.stream;

  @override
  Future<BackendInfo> info() async => const BackendInfo(
    nodeVersion: 'v24.20.0',
    backendVersion: 'fixture-backend',
    port: 3001,
  );

  @override
  Future<bool> isHealthy() async => true;

  @override
  Future<void> restart() async {}

  @override
  Future<void> start() async {
    starts++;
    _states.add(
      RuntimeState(status: RuntimeStatus.running, changedAt: DateTime.now()),
    );
  }

  @override
  Future<void> stop() async {
    stops++;
    _states.add(
      RuntimeState(status: RuntimeStatus.stopped, changedAt: DateTime.now()),
    );
  }

  @override
  Future<void> dispose() async {
    await _logs.close();
    await _states.close();
  }
}
