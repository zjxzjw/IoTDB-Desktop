import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iotdb_desktop/features/database/presentation/column_defs_editor.dart';
import 'package:iotdb_desktop/features/database/presentation/table_page.dart';

import '../helpers/fake_iotdb_client.dart';
import '../helpers/pump.dart';

Finder colNameField() => find
    .descendant(
      of: find.byType(ColumnDefsEditor),
      matching: find.byType(TextField),
    )
    .at(0);

Finder tableNameField() =>
    find.byKey(const Key('create-table-name'));
Finder commentField() =>
    find.byKey(const Key('create-table-comment'));
Finder ttlField() => find.byKey(const Key('create-table-ttl'));

void main() {
  final tableResult = qr(
    columns: ['TableName', 'TTL(ms)', 'Status', 'Comment'],
    rows: [
      ['t1', 'INF', 'USING', '表1'],
    ],
  );
  final columnsResult = qr(
    columns: ['ColumnName', 'DataType', 'Category', 'Status', 'Comment'],
    rows: [
      ['time', 'TIMESTAMP', 'TIME', 'USING', null],
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

  Future<void> openCreateForm(WidgetTester tester) async {
    await tester.tap(find.text('新建表'));
    await tester.pumpAndSettle();
    expect(tableNameField(), findsOneWidget);
  }

  testWidgets('创建表：自动补时间列 + 测点列', (tester) async {
    enlargeSurface(tester);
    final client = FakeIotdbClient();
    await tester.pumpWidget(build(client));
    await tester.pumpAndSettle();
    await openCreateForm(tester);
    await tester.enterText(tableNameField(), 'wind_turbine');
    await tester.enterText(colNameField(), 'temperature');
    await tester.tap(find.widgetWithText(FilledButton, '创建'));
    await tester.pumpAndSettle();
    expect(client.nonQuerySql, [
      'CREATE TABLE "demo"."wind_turbine" '
      '("time" TIMESTAMP TIME, "temperature" DOUBLE FIELD)',
    ]);
    expect(tableNameField(), findsNothing);
    expect(find.text('temperature'), findsWidgets);
  });

  testWidgets('创建表：带表注释与 TTL', (tester) async {
    enlargeSurface(tester);
    final client = FakeIotdbClient();
    await tester.pumpWidget(build(client));
    await tester.pumpAndSettle();
    await openCreateForm(tester);
    await tester.enterText(tableNameField(), 't1');
    await tester.enterText(commentField(), '风机');
    await tester.tap(find.text('设置表 TTL（可选，默认继承数据库 TTL）'));
    await tester.pumpAndSettle();
    await tester.enterText(ttlField(), '604800000');
    await tester.enterText(colNameField(), 'temp');
    await tester.tap(find.widgetWithText(FilledButton, '创建'));
    await tester.pumpAndSettle();
    final sql = client.nonQuerySql.single;
    expect(sql, contains('CREATE TABLE "demo"."t1"'));
    expect(sql, contains("COMMENT '风机'"));
    expect(sql, endsWith('WITH (TTL=604800000)'));
  });

  testWidgets('表名为空时阻止提交', (tester) async {
    enlargeSurface(tester);
    final client = FakeIotdbClient();
    await tester.pumpWidget(build(client));
    await tester.pumpAndSettle();
    await openCreateForm(tester);
    await tester.tap(find.widgetWithText(FilledButton, '创建'));
    await tester.pumpAndSettle();
    expect(client.nonQuerySql, isEmpty);
    expect(find.text('请输入表名'), findsOneWidget);
  });

  testWidgets('取消后恢复原表详情', (tester) async {
    enlargeSurface(tester);
    final client = FakeIotdbClient();
    await tester.pumpWidget(build(client));
    await tester.pumpAndSettle();
    await openCreateForm(tester);
    await tester.tap(find.widgetWithText(OutlinedButton, '取消'));
    await tester.pumpAndSettle();
    expect(tableNameField(), findsNothing);
    expect(find.text('temperature'), findsWidgets);
    expect(find.text('测点列'), findsWidgets);
  });

  testWidgets('右上角关闭按钮退出新建模式', (tester) async {
    enlargeSurface(tester);
    final client = FakeIotdbClient();
    await tester.pumpWidget(build(client));
    await tester.pumpAndSettle();
    await openCreateForm(tester);
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
    expect(tableNameField(), findsNothing);
    expect(find.text('temperature'), findsWidgets);
  });
}