import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iotdb_desktop/features/database/presentation/drop_database_dialog.dart';

import '../helpers/fake_iotdb_client.dart';
import '../helpers/pump.dart';
import '../helpers/test_connection.dart';

void main() {
  testWidgets('输入库名不匹配时删除按钮禁用，匹配后才可点击', (
    tester,
  ) async {
    enlargeSurface(tester);
    final client = FakeIotdbClient();
    final conn = testConnection();

    await tester.pumpWidget(
      wrapWithProvider(
        client: client,
        child: Consumer(
          builder: (context, ref, _) => ElevatedButton(
            onPressed: () =>
                showDropDatabaseDialog(context, ref, conn: conn, db: 'mydb'),
            child: const Text('打开'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    // 弹窗出现
    expect(find.text('删除数据库'), findsOneWidget);

    // 初始删除按钮禁用
    final deleteButton = find.widgetWithText(FilledButton, '删除');
    expect(tester.widget<FilledButton>(deleteButton).onPressed, isNull);

    // 输入错误库名仍禁用
    await tester.enterText(find.byType(TextFormField), 'wrong');
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(deleteButton).onPressed, isNull);

    // 输入正确库名后启用
    await tester.enterText(find.byType(TextFormField), 'mydb');
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(deleteButton).onPressed, isNotNull);
  });

  testWidgets('确认删除后执行 DROP DATABASE', (tester) async {
    enlargeSurface(tester);
    final client = FakeIotdbClient();
    final conn = testConnection();

    await tester.pumpWidget(
      wrapWithProvider(
        client: client,
        child: Consumer(
          builder: (context, ref, _) => ElevatedButton(
            onPressed: () =>
                showDropDatabaseDialog(context, ref, conn: conn, db: 'mydb'),
            child: const Text('打开'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'mydb');
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();

    expect(client.nonQuerySql, ['DROP DATABASE "mydb"']);
  });
}
