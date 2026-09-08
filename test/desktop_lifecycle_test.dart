import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sub_dock/desktop_lifecycle.dart';

void main() {
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
}
