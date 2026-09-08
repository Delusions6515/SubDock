import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

class DesktopLifecycle with WindowListener, TrayListener {
  DesktopLifecycle({required this.onExit, Directory? bundleDirectory})
    : _bundleDirectory =
          bundleDirectory ?? File(Platform.resolvedExecutable).parent;

  final Future<void> Function() onExit;
  final Directory _bundleDirectory;
  final warning = ValueNotifier<String?>(null);
  var _trayReady = false;
  var _exiting = false;

  Future<void> initialize() async {
    await windowManager.setPreventClose(true);
    windowManager.addListener(this);
    trayManager.addListener(this);
    try {
      await trayManager.setIcon(
        trayIconPath(
          bundleDirectory: _bundleDirectory,
          isWindows: Platform.isWindows,
        ),
      );
      if (traySupportsToolTip(isLinux: Platform.isLinux)) {
        await trayManager.setToolTip('SubDock');
      }
      await trayManager.setContextMenu(
        Menu(
          items: [
            MenuItem(key: 'show', label: '显示窗口'),
            MenuItem.separator(),
            MenuItem(key: 'exit', label: '退出'),
          ],
        ),
      );
      _trayReady = true;
    } catch (_) {
      warning.value = '系统托盘不可用；关闭窗口会退出 SubDock。';
    }
  }

  Future<void> exit() async {
    if (_exiting) return;
    _exiting = true;
    try {
      await onExit();
      if (_trayReady) await trayManager.destroy();
      await windowManager.destroy();
    } finally {
      windowManager.removeListener(this);
      trayManager.removeListener(this);
    }
  }

  Future<void> minimize() => windowManager.minimize();

  Future<void> toggleFullscreen() async {
    await windowManager.setFullScreen(!await windowManager.isFullScreen());
  }

  Future<void> closeToTray() => _closeWindow();

  @override
  void onWindowClose() => unawaited(_closeWindow());

  Future<void> _closeWindow() async {
    if (_exiting) return;
    if (_trayReady) {
      await windowManager.hide();
      return;
    }
    await exit();
  }

  @override
  void onTrayIconMouseDown() => unawaited(_showWindow());

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        unawaited(_showWindow());
      case 'exit':
        unawaited(exit());
    }
  }

  Future<void> _showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }
}

String trayIconPath({
  required Directory bundleDirectory,
  required bool isWindows,
}) => File.fromUri(
  bundleDirectory.uri.resolve('data/tray_icon${isWindows ? '.ico' : '.png'}'),
).path;

bool traySupportsToolTip({required bool isLinux}) => !isLinux;
