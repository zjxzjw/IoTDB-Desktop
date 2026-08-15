import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iotdb_desktop/features/database/presentation/create_table_form.dart';

import '../helpers/fake_iotdb_client.dart';
import '../helpers/pump.dart';

Finder fieldWithLabel(String label) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.labelText == label,
);

void main() {
  testWidgets('创建表：自动补时间列 + 测点列', (tester) async {
    enlargeSurface(tester);
    final client = FakeIotdbClient();
    await tester.pumpWidget(
      wrapWithProvider(
        client: client,
        child: const CreateTableSheet(db: 'demo'),
      ),
    );
    await tester.enterText(fieldWithLabel('表名 *'), 'wind_turbine');
    await tester.enterText(fieldWithLabel('列名 *'), 'temperature');
    await tester.tap(find.widgetWithText(FilledButton, '创建'));
    await tester.pumpAndSettle();
    expect(client.nonQuerySql, [
      'CREATE TABLE "demo"."wind_turbine" '
      '("time" TIMESTAMP TIME, "temperature" DOUBLE FIELD)',
    ]);
  });

  testWidgets('创建表：带表注释与 TTL', (tester) async {
    enlargeSurface(tester);
    final client = FakeIotdbClient();
    await tester.pumpWidget(
      wrapWithProvider(
        client: client,
        child: const CreateTableSheet(db: 'demo'),
      ),
    );
    await tester.enterText(fieldWithLabel('表名 *'), 't1');
    await tester.enterText(fieldWithLabel('表注释（可选）'), '风机');
    await tester.tap(find.text('设置表 TTL（可选，默认继承数据库 TTL）'));
    await tester.pumpAndSettle();
    await tester.enterText(fieldWithLabel('TTL（毫秒）'), '604800000');
    await tester.enterText(fieldWithLabel('列名 *'), 'temp');
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
    await tester.pumpWidget(
      wrapWithProvider(
        client: client,
        child: const CreateTableSheet(db: 'demo'),
      ),
    );
    await tester.tap(find.widgetWithText(FilledButton, '创建'));
    await tester.pumpAndSettle();
    expect(client.nonQuerySql, isEmpty);
    expect(find.text('请输入表名'), findsOneWidget);
  });
}
