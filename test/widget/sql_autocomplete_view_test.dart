import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iotdb_desktop/features/sql/presentation/sql_autocomplete.dart';
import 'package:re_editor/re_editor.dart';

void main() {
  Widget harness(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('渲染关键词与列提示', (tester) async {
    final notifier = ValueNotifier(
      const CodeAutocompleteEditingValue(
        input: 'se',
        prompts: [
          CodeKeywordPrompt(word: 'SELECT'),
          CodeFieldPrompt(word: 'serial', type: 'STRING'),
        ],
        index: 0,
      ),
    );
    addTearDown(notifier.dispose);
    await tester.pumpWidget(
      harness(
        SqlAutocompleteView(
          notifier: notifier,
          onSelected: (_) {},
          controller: SqlAutocompleteController(),
        ),
      ),
    );
    expect(find.text('SELECT'), findsOneWidget);
    expect(find.text('serial'), findsOneWidget);
  });

  testWidgets('点击选中项回调返回补全结果', (tester) async {
    final notifier = ValueNotifier(
      const CodeAutocompleteEditingValue(
        input: 'sel',
        prompts: [CodeKeywordPrompt(word: 'SELECT')],
        index: 0,
      ),
    );
    addTearDown(notifier.dispose);
    CodeAutocompleteResult? picked;
    await tester.pumpWidget(
      harness(
        SqlAutocompleteView(
          notifier: notifier,
          onSelected: (r) => picked = r,
          controller: SqlAutocompleteController(),
        ),
      ),
    );
    await tester.tap(find.text('SELECT'));
    expect(picked, isNotNull);
    expect(picked!.word, 'SELECT');
    expect(picked!.input, 'sel');
  });

  testWidgets('挂载时打开、卸载时关闭控制器', (tester) async {
    final notifier = ValueNotifier(
      const CodeAutocompleteEditingValue(
        input: 'se',
        prompts: [CodeKeywordPrompt(word: 'SELECT')],
        index: 0,
      ),
    );
    addTearDown(notifier.dispose);
    final controller = SqlAutocompleteController();
    await tester.pumpWidget(
      harness(
        SqlAutocompleteView(
          notifier: notifier,
          onSelected: (_) {},
          controller: controller,
        ),
      ),
    );
    expect(controller.isOpen, isTrue);
    expect(controller.autocomplete, isNotNull);

    await tester.pumpWidget(harness(const SizedBox()));
    expect(controller.isOpen, isFalse);
  });
}
