import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iotdb_desktop/features/database/presentation/create_database_form.dart';

import '../helpers/fake_iotdb_client.dart';
import '../helpers/pump.dart';

Finder fieldWithLabel(String label) => find.descendant(
  of: find
      .ancestor(of: find.text(label), matching: find.byType(Column))
      .first,
  matching: find.byType(TextField),
);

void main() {
  testWidgets('创建数据库：仅名称', (tester) async {
    final client = FakeIotdbClient();
    await tester.pumpWidget(
      wrapWithProvider(
        client: client,
        child: const CreateDatabaseDialog(),
      ),
    );
    await tester.enterText(fieldWithLabel('数据库名 *'), 'demo');
    await tester.tap(find.widgetWithText(FilledButton, '创建'));
    await tester.pumpAndSettle();
    expect(client.nonQuerySql, ['CREATE DATABASE "demo"']);
  });

  testWidgets('创建数据库：带 TTL', (tester) async {
    final client = FakeIotdbClient();
    await tester.pumpWidget(
      wrapWithProvider(
        client: client,
        child: const CreateDatabaseDialog(),
      ),
    );
    await tester.enterText(fieldWithLabel('数据库名 *'), 'demo');
    await tester.tap(find.text('设置 TTL'));
    await tester.pumpAndSettle();
    await tester.enterText(fieldWithLabel('TTL（毫秒）'), '604800000');
    await tester.tap(find.widgetWithText(FilledButton, '创建'));
    await tester.pumpAndSettle();
    expect(client.nonQuerySql, ['CREATE DATABASE "demo" WITH (TTL=604800000)']);
  });

  testWidgets('名称为空时阻止提交', (tester) async {
    final client = FakeIotdbClient();
    await tester.pumpWidget(
      wrapWithProvider(
        client: client,
        child: const CreateDatabaseDialog(),
      ),
    );
    await tester.tap(find.widgetWithText(FilledButton, '创建'));
    await tester.pumpAndSettle();
    expect(client.nonQuerySql, isEmpty);
    expect(find.text('请输入数据库名'), findsOneWidget);
  });
}
