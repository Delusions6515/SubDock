import 'package:flutter_test/flutter_test.dart';
import 'package:sub_dock/app/app.dart';

void main() {
  testWidgets('SubDock app starts correctly', (WidgetTester tester) async {
    // 构建应用
    await tester.pumpWidget(const SubDockApp());

    // 验证标题存在
    expect(find.text('SubDock'), findsOneWidget);
  });
}
