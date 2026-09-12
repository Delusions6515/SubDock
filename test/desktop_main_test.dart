import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subdock/desktop_main.dart';
import 'package:window_manager/window_manager.dart';

void main() {
  test('starts without a system title bar', () {
    expect(desktopWindowOptions().titleBarStyle, TitleBarStyle.hidden);
  });

  group('resolveEffectiveLocale', () {
    test('uses the system locale without a saved preference', () {
      expect(
        resolveEffectiveLocale(null, const [Locale('en')]),
        const Locale('en'),
      );
      expect(
        resolveEffectiveLocale(null, const [Locale('zh')]),
        const Locale('zh'),
      );
    });

    test('keeps a saved preference over the system locale', () {
      expect(
        resolveEffectiveLocale('zh', const [Locale('en')]),
        const Locale('zh'),
      );
      expect(
        resolveEffectiveLocale('en', const [Locale('zh')]),
        const Locale('en'),
      );
    });

    test('uses Flutter locale fallback for unsupported system locales', () {
      expect(
        resolveEffectiveLocale(null, const [Locale('fr')]),
        const Locale('en'),
      );
    });
  });
}
