import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iotdb_desktop/features/database/presentation/ttl_dialog.dart';

import '../helpers/fake_iotdb_client.dart';
import '../helpers/pump.dart';

Finder fieldWithLabel(String label) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.labelText == label,
);

void main() {
  Future<FakeIotdbClient> pumpDialog(
    WidgetTester tester, {
    required TtlTarget target,
    String table = 't1',
  }) async {
    final client = FakeIotdbClient();
    await tester.pumpWidget(
      wrapWithProvider(
        client: client,
        child: TtlDialog(target: target, db: 'demo', table: table),
      ),
    );
    return client;
  }

  testWidgets('表 TTL：自定义毫秒', (tester) async {
    final client = await pumpDialog(tester, target: TtlTarget.table);
    await tester.enterText(fieldWithLabel('TTL（毫秒）'), '3600');
    await tester.tap(find.widgetWithText(FilledButton, '确定'));
    await tester.pumpAndSettle();
    expect(client.nonQuerySql, ['ALTER TABLE "demo"."t1" SET PROPERTIES TTL=3600']);
  });

  testWidgets('表 TTL：INF', (tester) async {
    final client = await pumpDialog(tester, target: TtlTarget.table);
    await tester.tap(find.text('永久保存（INF）'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '确定'));
    await tester.pumpAndSettle();
    expect(client.nonQuerySql, ['ALTER TABLE "demo"."t1" SET PROPERTIES TTL=INF']);
  });

  testWidgets('表 TTL：恢复数据库默认', (tester) async {
    final client = await pumpDialog(tester, target: TtlTarget.table);
    await tester.tap(find.text('恢复数据库默认 TTL'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '确定'));
    await tester.pumpAndSettle();
    expect(
      client.nonQuerySql,
      ['ALTER TABLE "demo"."t1" SET PROPERTIES TTL=default'],
    );
  });

  testWidgets('数据库 TTL：自定义毫秒', (tester) async {
    final client = await pumpDialog(tester, target: TtlTarget.database);
    await tester.enterText(fieldWithLabel('TTL（毫秒）'), '604800000');
    await tester.tap(find.widgetWithText(FilledButton, '确定'));
    await tester.pumpAndSettle();
    expect(
      client.nonQuerySql,
      ['ALTER DATABASE "demo" SET PROPERTIES TTL=604800000'],
    );
  });

  testWidgets('非法 TTL 阻止提交', (tester) async {
    final client = await pumpDialog(tester, target: TtlTarget.table);
    await tester.enterText(fieldWithLabel('TTL（毫秒）'), 'abc');
    await tester.tap(find.widgetWithText(FilledButton, '确定'));
    await tester.pumpAndSettle();
    expect(client.nonQuerySql, isEmpty);
  });

  testWidgets('表 TTL：标题展示「设置表 TTL」并以徽章显示 db.table', (
    tester,
  ) async {
    await pumpDialog(tester, target: TtlTarget.table, table: 't1');
    expect(find.text('设置表 TTL'), findsOneWidget);
    expect(find.text('demo.t1'), findsOneWidget);
    expect(find.text('设置表 TTL · demo.t1'), findsNothing);
  });

  testWidgets('数据库 TTL：标题展示「设置数据库 TTL」并以徽章显示 db', (
    tester,
  ) async {
    await pumpDialog(tester, target: TtlTarget.database);
    expect(find.text('设置数据库 TTL'), findsOneWidget);
    expect(find.text('demo'), findsOneWidget);
    expect(find.text('设置数据库 TTL · demo'), findsNothing);
  });
}
