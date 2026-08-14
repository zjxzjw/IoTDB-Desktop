import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iotdb_desktop/app.dart';

void main() {
  testWidgets('应用启动冒烟测试', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: IotdbDesktopApp()));
    await tester.pump();
    expect(find.text('IoTDB Desktop'), findsOneWidget);
  });
}
