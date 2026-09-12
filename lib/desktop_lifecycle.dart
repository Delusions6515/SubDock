import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'settings/config_error.dart';

/// Resolves a tray menu label from its key in the current UI language.
/// The menu is a native OS menu with no BuildContext, so the label text is
/// produced by the caller (desktop_main) via a language callback.
typedef TrayLabelResolver = String Function(String key);

class DesktopLifecycle with WindowListener, TrayListener {
  DesktopLifecycle({
    required this.onExit,
    this.trayLabels,
    Directory? bundleDirectory,
  }) : _bundleDirectory =
          bundleDirectory ?? File(Platform.resolvedExecutable).parent;

  final Future<void> Function() onExit;
  final TrayLabelResolver? trayLabels;
  final Directory _bundleDirectory;
  final warning = ValueNotifier<Object?>(null);
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
      await _updateContextMenu();
      _trayReady = true;
    } catch (_) {
      warning.value = const AppConfigError(AppConfigErrorCode.trayUnavailable);
    }
  }

  /// Rebuilds the tray menu in the current language (KTD3). Safe to call
  /// before the tray is ready; it simply records the pending label state.
  Future<void> updateTray() async {
    if (!_trayReady) return;
    try {
      await _updateContextMenu();
    } catch (_) {
      warning.value = const AppConfigError(AppConfigErrorCode.trayUnavailable);
    }
  }

  Future<void> _updateContextMenu() {
    final labels = trayLabels;
    return trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(
            key: 'show',
            label: labels?.call('show') ?? 'Show window',
          ),
          MenuItem.separator(),
          MenuItem(key: 'exit', label: labels?.call('exit') ?? 'Exit'),
        ],
      ),
    );
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
