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
import 'settings/subdock_config_store.dart';
import 'update/component_metadata_store.dart';
import 'update/component_recovery.dart';
import 'update/component_resource_resolver.dart';
import 'update/component_update_service.dart';
import 'update/data_backup_store.dart';
import 'update/github_release_client.dart';

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
  String? startupBlocker;
  try {
    await ComponentRecovery(
      bundleDirectory: File(Platform.resolvedExecutable).parent,
      dataDirectory: directories.data,
      metadataStore: ComponentMetadataStore(directories.components),
      dataBackups: DataBackupStore(
        backupsDirectory: directories.backups,
        stagingDirectory: directories.staging,
      ),
    ).recoverPending();
  } catch (error) {
    startupBlocker = '组件更新恢复失败：$error';
  }
  final runtime = DesktopBackendRuntime(directories: directories);
  final metadataStore = ComponentMetadataStore(directories.components);
  final dataBackups = DataBackupStore(
    backupsDirectory: directories.backups,
    stagingDirectory: directories.staging,
  );
  final resources = ComponentResourceResolver(
    bundleDirectory: File(Platform.resolvedExecutable).parent,
    componentsDirectory: directories.components,
    metadataStore: metadataStore,
  );
  final coordinator = AppCoordinator(
    runtime: runtime,
    environmentStore: BackendEnvStore(directories),
    configurationStore: SubDockConfigStore(directories),
    startupBlocker: startupBlocker,
    componentUpdates: ComponentUpdateService(
      runtime: runtime,
      directories: directories,
      metadataStore: metadataStore,
      resources: resources,
      releases: GithubReleaseClient(),
      backups: dataBackups,
    ),
  );
  try {
    await coordinator.loadEnvironment();
  } on StateError {
    // The settings page provides the recovery path for an invalid saved ENV.
  }
  final lifecycle = DesktopLifecycle(onExit: coordinator.dispose);
  await lifecycle.initialize();
  await windowManager.waitUntilReadyToShow(desktopWindowOptions(), _showWindow);
  runApp(
    SubDockApp(
      coordinator: coordinator,
      autoStart: startupBlocker == null,
      initialError: startupBlocker,
      desktopWarning: lifecycle.warning,
      onMinimize: lifecycle.minimize,
      onToggleFullscreen: lifecycle.toggleFullscreen,
      onCloseToTray: lifecycle.closeToTray,
    ),
  );
}

Future<void> _showWindow() async {
  await windowManager.show();
  await windowManager.focus();
}

WindowOptions desktopWindowOptions() => const WindowOptions(
  title: 'SubDock',
  minimumSize: Size(600, 480),
  titleBarStyle: TitleBarStyle.hidden,
);
