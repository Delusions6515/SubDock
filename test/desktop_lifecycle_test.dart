import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sub_dock/desktop_lifecycle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('uses the packaged platform tray icon', () {
    final bundle = Directory('/opt/subdock');

    expect(
      trayIconPath(bundleDirectory: bundle, isWindows: false),
      '/opt/subdock/data/tray_icon.png',
    );
    expect(
      trayIconPath(bundleDirectory: bundle, isWindows: true),
      '/opt/subdock/data/tray_icon.ico',
    );
  });

  test('does not use unsupported Linux tray tooltips', () {
    expect(traySupportsToolTip(isLinux: true), isFalse);
    expect(traySupportsToolTip(isLinux: false), isTrue);
  });

  test('intercepts native close events before initializing the tray', () async {
    final windowCalls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const windowChannel = MethodChannel('window_manager');
    const trayChannel = MethodChannel('tray_manager');
    messenger.setMockMethodCallHandler(windowChannel, (call) async {
      windowCalls.add(call);
      return true;
    });
    messenger.setMockMethodCallHandler(trayChannel, (call) async => true);
    addTearDown(() {
      messenger.setMockMethodCallHandler(windowChannel, null);
      messenger.setMockMethodCallHandler(trayChannel, null);
    });

    await DesktopLifecycle(onExit: () async {}).initialize();

    expect(windowCalls, hasLength(1));
    expect(windowCalls.single.method, 'setPreventClose');
    expect(windowCalls.single.arguments, {'isPreventClose': true});
  });
}
