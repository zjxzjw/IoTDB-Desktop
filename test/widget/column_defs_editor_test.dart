import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iotdb_desktop/core/models/table_meta.dart';
import 'package:iotdb_desktop/features/database/presentation/column_defs_editor.dart';

Finder colNameField() => find.byType(TextField).at(0);

void main() {
  testWidgets('输入列名后产出 TableColumn（默认 FIELD/DOUBLE）', (tester) async {
    List<TableColumn>? emitted;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ColumnDefsEditor(onChanged: (cols) => emitted = cols),
        ),
      ),
    );
    await tester.enterText(colNameField(), 'temperature');
    await tester.pump();
    expect(emitted, isNotNull);
    expect(emitted!.length, 1);
    expect(emitted!.single.name, 'temperature');
    expect(emitted!.single.category, ColumnCategory.field);
    expect(emitted!.single.dataType, 'DOUBLE');
  });

  testWidgets('空列名不产出', (tester) async {
    List<TableColumn>? emitted;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ColumnDefsEditor(onChanged: (cols) => emitted = cols),
        ),
      ),
    );
    await tester.enterText(colNameField(), '   ');
    await tester.pump();
    expect(emitted, isNotNull);
    expect(emitted, isEmpty);
  });

  testWidgets('TAG 列类型固定 STRING', (tester) async {
    List<TableColumn>? emitted;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ColumnDefsEditor(onChanged: (cols) => emitted = cols),
        ),
      ),
    );
    await tester.enterText(colNameField(), 'device_id');
    // 类别下拉选择「标签列」（第二个选项）
    await tester.tap(find.byType(DropdownButton<ColumnCategory>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('标签列').last);
    await tester.pumpAndSettle();
    expect(emitted!.single.category, ColumnCategory.tag);
    expect(emitted!.single.dataType, 'STRING');
  });

  testWidgets('allowTimeCategory=false 时不提供时间列选项', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ColumnDefsEditor(
            onChanged: (_) {},
            allowTimeCategory: false,
          ),
        ),
      ),
    );
    await tester.tap(find.byType(DropdownButton<ColumnCategory>));
    await tester.pumpAndSettle();
    expect(find.text('时间列'), findsNothing);
    expect(find.text('标签列'), findsOneWidget);
    expect(find.text('属性列'), findsOneWidget);
    // 「测点列」同时出现在按钮选中项与菜单项
    expect(find.text('测点列'), findsWidgets);
  });

  testWidgets('添加/删除行', (tester) async {
    List<TableColumn>? emitted;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ColumnDefsEditor(onChanged: (cols) => emitted = cols),
        ),
      ),
    );
    await tester.enterText(colNameField(), 'a');
    await tester.tap(find.text('添加列'));
    await tester.pumpAndSettle();
    expect(find.text('添加列'), findsOneWidget);
    // 两行：第二行列名为空 → 仅产出第一行
    expect(emitted!.length, 1);
    expect(emitted!.single.name, 'a');
  });
}
