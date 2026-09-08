import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:windows_single_instance/windows_single_instance.dart';

import 'app/app.dart';
import 'app/app_coordinator.dart';
import 'desktop_lifecycle.dart';
import 'runtime/desktop_backend_runtime.dart';
import 'runtime/runtime_directories.dart';
import 'settings/backend_env_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  if (Platform.isWindows) {
    await WindowsSingleInstance.ensureSingleInstance(
      Platform.executableArguments,
      'subdock',
      onSecondWindow: (_) => unawaited(_showWindow()),
    );
  }
  final directories = await RuntimeDirectories.create();
  final runtime = DesktopBackendRuntime(directories: directories);
  final coordinator = AppCoordinator(
    runtime: runtime,
    environmentStore: BackendEnvStore(directories),
  );
  try {
    await coordinator.loadEnvironment();
  } on StateError {
    // The settings page provides the recovery path for an invalid saved ENV.
  }
  final lifecycle = DesktopLifecycle(onExit: coordinator.dispose);
  await lifecycle.initialize();
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(title: 'SubDock', minimumSize: Size(600, 480)),
    _showWindow,
  );
  runApp(
    SubDockApp(
      coordinator: coordinator,
      desktopWarning: lifecycle.warning,
      onExit: lifecycle.exit,
    ),
  );
}

Future<void> _showWindow() async {
  await windowManager.show();
  await windowManager.focus();
}
