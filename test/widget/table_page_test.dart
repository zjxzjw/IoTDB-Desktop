import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iotdb_desktop/features/database/presentation/table_page.dart';

import '../helpers/fake_iotdb_client.dart';
import '../helpers/pump.dart';

void main() {
  final tableResult = qr(
    columns: ['TableName', 'TTL(ms)', 'Status', 'Comment'],
    rows: [
      ['t1', 'INF', 'USING', '表1'],
      ['t2', '3600', 'USING', null],
    ],
  );
  final columnsResult = qr(
    columns: ['ColumnName', 'DataType', 'Category', 'Status', 'Comment'],
    rows: [
      ['time', 'TIMESTAMP', 'TIME', 'USING', null],
      ['device_id', 'STRING', 'TAG', 'USING', null],
      ['temperature', 'FLOAT', 'FIELD', 'USING', '温度'],
    ],
  );

  Widget build(FakeIotdbClient client) {
    return wrapWithProvider(
      client: client,
      db: 'demo',
      table: 't1',
      tables: tableResult,
      columns: columnsResult,
      child: const TablePage(),
    );
  }

  testWidgets('渲染表列表与列结构', (tester) async {
    enlargeSurface(tester);
    await tester.pumpWidget(build(FakeIotdbClient()));
    await tester.pumpAndSettle();
    expect(find.text('t1'), findsWidgets);
    expect(find.text('t2'), findsWidgets);
    expect(find.text('temperature'), findsWidgets);
    expect(find.text('FLOAT'), findsWidgets);
    expect(find.text('测点列'), findsWidgets);
    expect(find.text('标签列'), findsWidgets);
    expect(find.text('时间列'), findsWidgets);
  });

  testWidgets('删除测点列流程', (tester) async {
    enlargeSurface(tester);
    final client = FakeIotdbClient();
    await tester.pumpWidget(build(client));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('删除列'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();
    expect(
      client.nonQuerySql,
      contains('ALTER TABLE "demo"."t1" DROP COLUMN IF EXISTS "temperature"'),
    );
  });

  testWidgets('删除表流程', (tester) async {
    enlargeSurface(tester);
    final client = FakeIotdbClient();
    await tester.pumpWidget(build(client));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('删除表'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();
    expect(client.nonQuerySql, contains('DROP TABLE IF EXISTS "demo"."t1"'));
  });

  testWidgets('未选数据库时显示提示', (tester) async {
    enlargeSurface(tester);
    final client = FakeIotdbClient();
    await tester.pumpWidget(
      wrapWithProvider(client: client, child: const TablePage()),
    );
    await tester.pumpAndSettle();
    expect(find.text('请先在左侧连接中选择数据库'), findsOneWidget);
  });
}
