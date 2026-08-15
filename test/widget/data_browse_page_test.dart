import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iotdb_desktop/features/data/presentation/data_browse_page.dart';

import '../helpers/fake_iotdb_client.dart';
import '../helpers/pump.dart';

Finder fieldWithLabel(String label) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.labelText == label,
);

void main() {
  final dbResult = qr(
    columns: ['Database'],
    rows: [['demo']],
  );
  final tableResult = qr(
    columns: ['TableName'],
    rows: [['wind_turbine']],
  );
  final columnsResult = qr(
    columns: ['ColumnName', 'DataType', 'Category'],
    rows: [
      ['time', 'TIMESTAMP', 'TIME'],
      ['device_id', 'STRING', 'TAG'],
      ['region', 'STRING', 'TAG'],
      ['temperature', 'FLOAT', 'FIELD'],
      ['humidity', 'DOUBLE', 'FIELD'],
    ],
  );

  Widget build(FakeIotdbClient client) {
    return wrapWithProvider(
      client: client,
      db: 'demo',
      table: 'wind_turbine',
      dbList: dbResult,
      tables: tableResult,
      columns: columnsResult,
      child: const DataBrowsePage(),
    );
  }

  testWidgets('从侧栏预填 + 自动选默认列 + 查询生成三条 SQL', (tester) async {
    enlargeSurface(tester);
    final client = FakeIotdbClient();
    await tester.pumpWidget(build(client));
    await tester.pumpAndSettle();

    expect(find.text('wind_turbine'), findsOneWidget);
    // 默认选中：TAG + FIELD 列
    expect(
      find.widgetWithText(FilterChip, 'device_id · 标签列'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(FilterChip, 'temperature · 测点列'),
      findsOneWidget,
    );

    await tester.tap(find.text('查询'));
    await tester.pumpAndSettle();

    final sqls = client.querySql;
    expect(sqls.length, 3, reason: '应生成 raw/count/chart 三条查询');
    expect(
      sqls.any((s) =>
          s.startsWith('SELECT count(*) FROM "demo"."wind_turbine"')),
      isTrue,
      reason: 'countSql: $sqls',
    );
    expect(
      sqls.any((s) =>
          s.contains('FROM "demo"."wind_turbine" WHERE time >= ') &&
          s.contains('LIMIT 100 OFFSET 0')),
      isTrue,
      reason: 'rawSql: $sqls',
    );
    expect(
      sqls.any((s) => s.contains('date_bin_gapfill(5m, time)')),
      isTrue,
      reason: 'chartSql: $sqls',
    );
  });

  testWidgets('TAG 过滤进入 WHERE', (tester) async {
    enlargeSurface(tester);
    final client = FakeIotdbClient();
    await tester.pumpWidget(build(client));
    await tester.pumpAndSettle();

    await tester.enterText(fieldWithLabel('device_id'), 'd1');
    await tester.pumpAndSettle();
    await tester.tap(find.text('查询'));
    await tester.pumpAndSettle();

    final raw = client.querySql.firstWhere(
      (s) => s.contains('LIMIT 100 OFFSET 0'),
    );
    expect(raw, contains('"device_id" = \'d1\''));
  });
}
