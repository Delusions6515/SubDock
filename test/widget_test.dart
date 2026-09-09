import 'dart:async';
import 'dart:io';
import 'dart:ui' show Size;

import 'package:flutter/material.dart'
    show FilledButton, NavigationBar, NavigationRail, OutlinedButton;
import 'package:flutter/scheduler.dart' show AppLifecycleState;
import 'package:flutter/widgets.dart' show Offstage, SizedBox, ValueKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:subdock/app/app.dart';
import 'package:subdock/app/app_coordinator.dart';
import 'package:subdock/runtime/backend_runtime.dart';
import 'package:subdock/runtime/runtime_directories.dart';
import 'package:subdock/settings/backend_env_store.dart';

void main() {
  testWidgets('runtime controls the backend through its abstraction', (
    WidgetTester tester,
  ) async {
    late Directory temp;
    addTearDown(() => tester.runAsync(() => temp.delete(recursive: true)));
    final runtime = _FakeBackendRuntime();
    final directories = await tester.runAsync(() async {
      temp = await Directory.systemTemp.createTemp('subdock_widget_');
      return RuntimeDirectories.fromBaseDirectory(temp);
    });
    final coordinator = AppCoordinator(
      runtime: runtime,
      environmentStore: BackendEnvStore(directories!),
    );

    await tester.pumpWidget(
      SubDockApp(
        coordinator: coordinator,
        autoStart: false,
        enableWebView: false,
      ),
    );

    await tester.tap(find.text('运行状态'));
    await tester.pump();

    final managementPage = find.byKey(const ValueKey('page-manage'));
    expect(managementPage, findsOneWidget);
    expect(tester.widget<Offstage>(managementPage).offstage, isTrue);
    expect(find.text('已停止'), findsOneWidget);
    expect(find.text('Node'), findsOneWidget);
    expect(find.text('Backend'), findsOneWidget);
    expect(find.text('Port'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '启动'))
          .onPressed,
      isNotNull,
    );

    tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, '启动'))
        .onPressed!();
    await tester.pump(const Duration(milliseconds: 1));

    expect(runtime.starts, 1);
    expect(find.text('运行中'), findsOneWidget);
    expect(find.text('v24.20.0'), findsOneWidget);
    expect(find.text('fixture-backend'), findsOneWidget);
    expect(find.text('3001'), findsOneWidget);

    tester
        .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, '停止'))
        .onPressed!();
    await tester.pump(const Duration(milliseconds: 1));

    expect(runtime.stops, 1);
    expect(find.text('已停止'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('app stops the runtime when it detaches', (
    WidgetTester tester,
  ) async {
    late Directory temp;
    addTearDown(() => tester.runAsync(() => temp.delete(recursive: true)));
    final runtime = _FakeBackendRuntime();
    final directories = await tester.runAsync(() async {
      temp = await Directory.systemTemp.createTemp('subdock_widget_');
      return RuntimeDirectories.fromBaseDirectory(temp);
    });
    final coordinator = AppCoordinator(
      runtime: runtime,
      environmentStore: BackendEnvStore(directories!),
    );

    await tester.pumpWidget(
      SubDockApp(
        coordinator: coordinator,
        autoStart: false,
        enableWebView: false,
      ),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.detached);
    await tester.pump();

    expect(runtime.stops, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'desktop controls minimize, toggle fullscreen, and close to tray',
    (WidgetTester tester) async {
      late Directory temp;
      addTearDown(() => tester.runAsync(() => temp.delete(recursive: true)));
      final directories = await tester.runAsync(() async {
        temp = await Directory.systemTemp.createTemp('subdock_widget_');
        return RuntimeDirectories.fromBaseDirectory(temp);
      });
      final coordinator = AppCoordinator(
        runtime: _FakeBackendRuntime(),
        environmentStore: BackendEnvStore(directories!),
      );
      var minimizes = 0;
      var fullscreenToggles = 0;
      var closesToTray = 0;

      await tester.pumpWidget(
        SubDockApp(
          coordinator: coordinator,
          autoStart: false,
          enableWebView: false,
          onMinimize: () async => minimizes++,
          onToggleFullscreen: () async => fullscreenToggles++,
          onCloseToTray: () async => closesToTray++,
        ),
      );

      await tester.tap(find.byTooltip('最小化'));
      await tester.tap(find.byTooltip('切换全屏'));
      await tester.tap(find.byTooltip('关闭到托盘'));

      expect(minimizes, 1);
      expect(fullscreenToggles, 1);
      expect(closesToTray, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('uses a navigation bar below the 600 pixel breakpoint', (
    WidgetTester tester,
  ) async {
    late Directory temp;
    addTearDown(() => tester.runAsync(() => temp.delete(recursive: true)));
    final runtime = _FakeBackendRuntime();
    final directories = await tester.runAsync(() async {
      temp = await Directory.systemTemp.createTemp('subdock_widget_');
      return RuntimeDirectories.fromBaseDirectory(temp);
    });
    final coordinator = AppCoordinator(
      runtime: runtime,
      environmentStore: BackendEnvStore(directories!),
    );
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.binding.setSurfaceSize(const Size(599, 800));
    await tester.pumpWidget(
      SubDockApp(
        coordinator: coordinator,
        autoStart: false,
        enableWebView: false,
      ),
    );
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.binding.setSurfaceSize(const Size(600, 800));
    await tester.pump();
    expect(find.byType(NavigationRail), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}

class _FakeBackendRuntime extends BackendRuntime {
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
  Future<void> activateUserEnvironment(Map<String, String> environment) async {}

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
    await stop();
    await _logs.close();
    await _states.close();
  }
}
