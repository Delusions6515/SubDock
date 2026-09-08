import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

class DesktopLifecycle with WindowListener, TrayListener {
  DesktopLifecycle({required this.onExit});

  final Future<void> Function() onExit;
  final warning = ValueNotifier<String?>(null);
  var _trayReady = false;
  var _exiting = false;

  Future<void> initialize() async {
    windowManager.addListener(this);
    trayManager.addListener(this);
    try {
      await trayManager.setIcon(
        Platform.isWindows
            ? 'windows/runner/resources/app_icon.ico'
            : 'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_32.png',
      );
      await trayManager.setToolTip('SubDock');
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
