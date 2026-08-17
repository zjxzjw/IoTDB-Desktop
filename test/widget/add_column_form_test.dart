import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iotdb_desktop/features/database/presentation/add_column_form.dart';
import 'package:iotdb_desktop/features/database/presentation/column_defs_editor.dart';

import '../helpers/fake_iotdb_client.dart';
import '../helpers/pump.dart';

Finder colNameField() => find
    .descendant(
      of: find.byType(ColumnDefsEditor),
      matching: find.byType(TextField),
    )
    .at(0);

void main() {
  testWidgets('加列：产出 ALTER TABLE ... ADD COLUMN', (tester) async {
    final client = FakeIotdbClient();
    await tester.pumpWidget(
      wrapWithProvider(
        client: client,
        child: const AddColumnDialog(db: 'demo', table: 't1'),
      ),
    );
    await tester.enterText(colNameField(), 'humidity');
    await tester.tap(find.widgetWithText(FilledButton, '添加'));
    await tester.pumpAndSettle();
    expect(client.nonQuerySql, [
      'ALTER TABLE "demo"."t1" ADD COLUMN IF NOT EXISTS "humidity" DOUBLE FIELD',
    ]);
  });

  testWidgets('列名为空时阻止提交', (tester) async {
    final client = FakeIotdbClient();
    await tester.pumpWidget(
      wrapWithProvider(
        client: client,
        child: const AddColumnDialog(db: 'demo', table: 't1'),
      ),
    );
    await tester.tap(find.widgetWithText(FilledButton, '添加'));
    await tester.pumpAndSettle();
    expect(client.nonQuerySql, isEmpty);
  });
}