import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:iotdb_desktop/core/theme/shadcn_tokens.dart';
import 'package:iotdb_desktop/shared/result_table.dart';

void main() {
  testWidgets('渲染表头与数据行', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ResultTable(
            columns: ['time', 'value'],
            rows: [
              [1700000000000, 1.5],
              [1700000001000, 2.0],
            ],
          ),
        ),
      ),
    );
    expect(find.text('time'), findsOneWidget);
    expect(find.text('value'), findsOneWidget);
    expect(find.text('1.5'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('time 列格式化为日期时间', (tester) async {
    const ts = 1700000000000;
    final expected = DateFormat(
      'yyyy-MM-dd HH:mm:ss.SSS',
    ).format(DateTime.fromMillisecondsSinceEpoch(ts));
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ResultTable(
            columns: ['time', 'v'],
            rows: [
              [ts, 'x'],
            ],
          ),
        ),
      ),
    );
    expect(find.text(expected), findsOneWidget);
  });

  testWidgets('null 显示为 null', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ResultTable(
            columns: ['a', 'b'],
            rows: [
              [null, 1],
            ],
          ),
        ),
      ),
    );
    expect(find.text('null'), findsOneWidget);
  });

  testWidgets('空结果显示空态', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ResultTable(columns: ['a'], rows: [])),
      ),
    );
    expect(find.text('查询结果为空'), findsOneWidget);
  });

  testWidgets('多页分页', (tester) async {
    final rows = [
      for (var i = 0; i < 250; i++) [i],
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResultTable(columns: ['idx'], rows: rows, pageSize: 100),
        ),
      ),
    );
    expect(find.text('共 250 行'), findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    expect(find.text('2 / 3'), findsOneWidget);
  });

  testWidgets('拖拽表头右缘可调整列宽', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ResultTable(
            columns: ['time', 'value'],
            rows: [
              [1700000000000, 1.5],
            ],
          ),
        ),
      ),
    );

    final before = tester
        .getSize(find.byKey(const ValueKey('result-col-0')))
        .width;
    await tester.drag(
      find.byKey(const ValueKey('result-col-resize-0')),
      const Offset(-100, 0),
    );
    await tester.pumpAndSettle();
    final after = tester
        .getSize(find.byKey(const ValueKey('result-col-0')))
        .width;
    expect(after, lessThan(before), reason: '拖动后列宽应缩短');

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ResultTable(
            columns: ['a', 'b', 'c'],
            rows: [
              [1, 2, 3],
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final reset = tester
        .getSize(find.byKey(const ValueKey('result-col-0')))
        .width;
    expect(reset, closeTo(800 / 3, 1), reason: '列数变化后自定义列宽应重置');
  });

  testWidgets('双击表头右缘恢复自适应列宽', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ResultTable(
            columns: ['time', 'value'],
            rows: [
              [1700000000000, 1.5],
            ],
          ),
        ),
      ),
    );

    final before = tester
        .getSize(find.byKey(const ValueKey('result-col-0')))
        .width;
    await tester.drag(
      find.byKey(const ValueKey('result-col-resize-0')),
      const Offset(-100, 0),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const ValueKey('result-col-0'))).width,
      lessThan(before),
      reason: '拖动后列宽应变化',
    );

    final handle = find.byKey(const ValueKey('result-col-resize-0'));
    await tester.tap(handle);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(handle);
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const ValueKey('result-col-0'))).width,
      closeTo(before, 1),
      reason: '双击后列宽应恢复自适应',
    );
  });

  testWidgets('列宽超过视口时可横向滚动', (tester) async {
    final columns = [for (var i = 0; i < 12; i++) 'col$i'];
    final rows = [
      for (var r = 0; r < 20; r++) [for (var i = 0; i < 12; i++) 'r${r}c$i'],
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: ResultTable(columns: columns, rows: rows),
          ),
        ),
      ),
    );

    final scrollables = find.byType(Scrollable);
    final hPosition = tester.state<ScrollableState>(scrollables.first).position;
    expect(hPosition.axis, Axis.horizontal, reason: '外层应为横向滚动');
    expect(hPosition.maxScrollExtent, greaterThan(0), reason: '内容超过视口应可横向滚动');
    expect(find.byType(Scrollbar), findsWidgets, reason: '应提供可见滚动条');
  });

  testWidgets('表头与表体单元格带垂直分割线', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ResultTable(
            columns: ['a', 'b'],
            rows: [
              ['x', 'y'],
            ],
          ),
        ),
      ),
    );
    BoxDecoration? cellDecoration(Widget keyWidget) {
      final container = tester.widget<Container>(
        find
            .ancestor(of: find.byWidget(keyWidget), matching: find.byType(Container))
            .first,
      );
      return container.decoration as BoxDecoration?;
    }

    final headerCell = tester.widget(find.byKey(const ValueKey('result-col-0')));
    final headerDeco = cellDecoration(headerCell);
    expect(headerDeco, isNotNull, reason: '表头单元格应带边框装饰');
    final headerBorder = headerDeco!.border as Border?;
    expect(headerBorder, isNotNull, reason: '表头单元格应有边框');
    expect(headerBorder!.right, isA<BorderSide>(), reason: '表头单元格右缘应有分割线');
    expect(headerBorder.right.color, ShadTokens.divider);
  });
}
