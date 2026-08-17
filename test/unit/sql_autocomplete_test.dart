import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iotdb_desktop/core/models/table_meta.dart';
import 'package:iotdb_desktop/features/sql/presentation/sql_autocomplete.dart';
import 'package:re_editor/re_editor.dart';

const _columns = {
  'sensors': [
    TableColumn(
      name: 'id',
      dataType: 'INT64',
      category: ColumnCategory.tag,
    ),
    TableColumn(
      name: 'value',
      dataType: 'DOUBLE',
      category: ColumnCategory.field,
    ),
    TableColumn(
      name: 'time',
      dataType: 'TIMESTAMP',
      category: ColumnCategory.time,
    ),
  ],
  'devices': [
    TableColumn(
      name: 'serial',
      dataType: 'STRING',
      category: ColumnCategory.attribute,
    ),
    TableColumn(
      name: 'voltage',
      dataType: 'FLOAT',
      category: ColumnCategory.field,
    ),
  ],
};

const _data = SqlAutocompleteData(
  db: 'root.test',
  keywords: ['SELECT', 'FROM', 'WHERE', 'CREATE', 'TABLE'],
  tables: ['sensors', 'devices'],
  columnsByTable: _columns,
);

Future<BuildContext> _grabContext(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
  return tester.element(find.byType(MaterialApp));
}

CodeAutocompleteEditingValue? _build(
  BuildContext context,
  String text,
) {
  final controller = CodeLineEditingController.fromText(text);
  controller.selection = CodeLineSelection(
    baseIndex: 0,
    baseOffset: text.length,
    extentIndex: 0,
    extentOffset: text.length,
  );
  final builder = SqlAutocompletePromptsBuilder(
    controller: controller,
    data: _data,
  );
  final line = controller.value.codeLines[0];
  return builder.build(context, line, controller.selection);
}

List<String> _words(CodeAutocompleteEditingValue? v) =>
    [for (final p in v?.prompts ?? const <CodePrompt>[]) p.word];

void main() {
  testWidgets('大小写不敏感匹配关键词', (tester) async {
    final ctx = await _grabContext(tester);
    final v = _build(ctx, 'SE');
    expect(v, isNotNull);
    final words = _words(v);
    expect(words, contains('SELECT'));
    expect(words.first, 'SELECT');
  });

  testWidgets('FROM 上下文（空输入）建议全部表名', (tester) async {
    final ctx = await _grabContext(tester);
    final v = _build(ctx, 'SELECT * FROM ');
    expect(v, isNotNull);
    final words = _words(v);
    expect(words, containsAll(['sensors', 'devices']));
    expect(words.indexOf('sensors'), lessThan(words.indexOf('devices')));
  });

  testWidgets('FROM 上下文输入前缀时表名优先', (tester) async {
    final ctx = await _grabContext(tester);
    final v = _build(ctx, 'SELECT * FROM sen');
    expect(v, isNotNull);
    final words = _words(v);
    expect(words.first, 'sensors');
  });

  testWidgets('表名选中后插入库.表 全限定名', (tester) async {
    final ctx = await _grabContext(tester);
    final v = _build(ctx, 'SELECT * FROM sen');
    expect(v, isNotNull);
    final result = v!.autocomplete;
    expect(result.word, '"root.test"."sensors"');
    expect(result.input, 'sen');
  });

  testWidgets('SELECT 上下文建议列', (tester) async {
    final ctx = await _grabContext(tester);
    final v = _build(ctx, 'SELECT ');
    expect(v, isNotNull);
    final words = _words(v);
    expect(words, containsAll(['id', 'value', 'time', 'serial', 'voltage']));
    expect(words.indexOf('value'), lessThan(words.indexOf('voltage')));
  });

  testWidgets('SELECT 上下文前缀匹配列', (tester) async {
    final ctx = await _grabContext(tester);
    final v = _build(ctx, 'SELECT vol');
    expect(v, isNotNull);
    expect(_words(v).first, 'voltage');
  });

  testWidgets('表名. 成员访问建议该表列', (tester) async {
    final ctx = await _grabContext(tester);
    final v = _build(ctx, 'SELECT "sensors".v');
    expect(v, isNotNull);
    final words = _words(v);
    expect(words, ['value']);
  });

  testWidgets('别名. 成员访问解析到原表列', (tester) async {
    final ctx = await _grabContext(tester);
    final v = _build(ctx, 'SELECT * FROM sensors AS s WHERE s.');
    expect(v, isNotNull);
    expect(_words(v), containsAll(['id', 'value', 'time']));
  });

  testWidgets('引号限定表名成员访问', (tester) async {
    final ctx = await _grabContext(tester);
    final v = _build(ctx, 'SELECT * FROM "db"."sensors" WHERE "sensors".i');
    expect(v, isNotNull);
    final words = _words(v);
    expect(words, containsAll(['id', 'time']));
    expect(words, isNot(contains('voltage')));
  });

  testWidgets('CREATE TABLE 上下文建议数据类型', (tester) async {
    final ctx = await _grabContext(tester);
    final v = _build(ctx, 'CREATE TABLE t (');
    expect(v, isNotNull);
    expect(_words(v), contains('INT64'));
  });

  testWidgets('CREATE TABLE 输入 INT 前缀建议 INT32/INT64', (tester) async {
    final ctx = await _grabContext(tester);
    final v = _build(ctx, 'CREATE TABLE t (INT');
    expect(v, isNotNull);
    final words = _words(v);
    expect(words, containsAll(['INT32', 'INT64']));
  });

  testWidgets('无上下文且空输入时不弹窗', (tester) async {
    final ctx = await _grabContext(tester);
    final v = _build(ctx, ' ');
    expect(v, isNull);
  });

  testWidgets('字符串内部不弹窗', (tester) async {
    final ctx = await _grabContext(tester);
    final v = _build(ctx, "SELECT 'abc");
    expect(v, isNull);
  });

  testWidgets('-- 注释内部不弹窗', (tester) async {
    final ctx = await _grabContext(tester);
    final v = _build(ctx, 'SELECT * FROM -- note');
    expect(v, isNull);
  });

  test('SqlAutocompleteController 开关状态与 autocomplete', () {
    final c = SqlAutocompleteController();
    expect(c.isOpen, false);
    final v = const CodeAutocompleteEditingValue(
      input: 'sel',
      prompts: [CodeKeywordPrompt(word: 'SELECT')],
      index: 0,
    );
    c.opened(v);
    expect(c.isOpen, true);
    expect(c.autocomplete!.word, 'SELECT');
    c.closed();
    expect(c.isOpen, false);
    expect(c.autocomplete, isNull);
  });

  test('SqlKeywords 包含 langSql 与 IoTDB 关键词且为大写去重', () {
    final all = SqlKeywords.all;
    expect(all.contains('SELECT'), isTrue);
    expect(all.contains('DATABASE'), isTrue);
    expect(all.contains('DATABASES'), isTrue);
    expect(all.contains('select'), isFalse);
    expect(all.toSet().length, all.length);
  });
}
