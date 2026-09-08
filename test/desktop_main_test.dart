import 'package:flutter_test/flutter_test.dart';
import 'package:sub_dock/desktop_main.dart';
import 'package:window_manager/window_manager.dart';

void main() {
  test('starts without a system title bar', () {
    expect(desktopWindowOptions().titleBarStyle, TitleBarStyle.hidden);
  });
}
