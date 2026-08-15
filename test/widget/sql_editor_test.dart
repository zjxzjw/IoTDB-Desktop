import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iotdb_desktop/features/sql/presentation/sql_editor.dart';
import 'package:re_editor/re_editor.dart';

void main() {
  testWidgets('SQL 编辑器渲染正常', (tester) async {
    final controller = CodeLineEditingController();
    final focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 400,
            child: SqlEditor(
              controller: controller,
              focusNode: focus,
              onRun: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SqlEditor), findsOneWidget);
  });

  testWidgets('Cmd/Ctrl+Enter 触发执行', (tester) async {
    final controller = CodeLineEditingController();
    final focus = FocusNode();
    var runs = 0;
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 400,
            child: SqlEditor(
              controller: controller,
              focusNode: focus,
              onRun: () => runs++,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 不请求焦点，避免 re_editor 光标闪烁计时器导致测试断言挂起
    await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
    await tester.pump();

    expect(runs, 1);

    // 冲刷 re_editor 内部延迟任务，避免残留计时器
    await tester.pump(const Duration(seconds: 10));
  });
}
