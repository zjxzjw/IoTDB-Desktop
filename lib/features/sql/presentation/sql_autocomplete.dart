import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/languages/sql.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/models/table_meta.dart';
import '../../../core/theme/shadcn_tokens.dart';

/// 补全数据：关键词 + 表 + 列（由工作台页从 Riverpod provider 组装后传入编辑器）
class SqlAutocompleteData {
  /// 当前库名（用于表名补全插入 `"库"."表"` 限定名）
  final String db;
  final List<String> keywords;
  final List<String> tables;
  final Map<String, List<TableColumn>> columnsByTable;

  const SqlAutocompleteData({
    this.db = '',
    required this.keywords,
    this.tables = const [],
    this.columnsByTable = const {},
  });
}

/// 供 Tab 键接受补全使用的控制器：SqlAutocompleteView 挂载/卸载时同步开关状态
class SqlAutocompleteController {
  bool isOpen = false;
  CodeAutocompleteEditingValue? value;

  void opened(CodeAutocompleteEditingValue v) {
    isOpen = true;
    value = v;
  }

  void closed() {
    isOpen = false;
    value = null;
  }

  CodeAutocompleteResult? get autocomplete => value?.autocomplete;
}

/// SQL 关键词来源：langSql 关键词 + IoTDB 专属关键词（统一大写、去重）
abstract final class SqlKeywords {
  static List<String> get all {
    final set = <String>{
      ..._fromLang(),
      ...iotdb,
    };
    return set.toList()..sort();
  }

  static List<String> _fromLang() {
    final kws = langSql.keywords;
    if (kws is! Map) return const [];
    final out = <String>{};
    for (final key in const ['keyword', 'built_in', 'literal', 'type']) {
      final v = kws[key];
      if (v is List) {
        for (final e in v) {
          final word = e.toString().split('|').first.trim();
          if (word.isNotEmpty) out.add(word.toUpperCase());
        }
      }
    }
    return out.toList();
  }

  static const List<String> iotdb = [
    'DATABASE',
    'DATABASES',
    'STORAGE',
    'GROUP',
    'GROUPS',
    'TABLE',
    'TABLES',
    'DEVICE',
    'DEVICES',
    'MEASUREMENT',
    'MEASUREMENTS',
    'TIMESERIES',
    'TAGS',
    'ATTRIBUTE',
    'ATTRIBUTES',
    'FIELD',
    'FIELDS',
    'TIME',
    'TIMESTAMP',
    'TTL',
    'INF',
    'DETAILS',
    'SHOW',
    'DESC',
    'DESCRIBE',
    'ALTER',
    'SET',
    'PROPERTIES',
    'UNLINK',
    'CREATE',
    'DROP',
    'INSERT',
    'INTO',
    'VALUES',
    'SELECT',
    'FROM',
    'WHERE',
    'GROUP',
    'ORDER',
    'BY',
    'HAVING',
    'LIMIT',
    'OFFSET',
    'OFFSETS',
    'ALIGN',
    'ALIGNED',
    'DEALIGNED',
    'COUNT',
    'SUM',
    'AVG',
    'MIN',
    'MAX',
    'FIRST',
    'LAST',
    'NOW',
    'CONCAT',
    'DIFF',
    'CASE',
    'WHEN',
    'THEN',
    'ELSE',
    'END',
    'AS',
    'AND',
    'OR',
    'NOT',
    'NULL',
    'IS',
    'IN',
    'EXISTS',
    'BETWEEN',
    'LIKE',
    'DISTINCT',
    'ALL',
    'ANY',
    'SOME',
    'ASC',
    'DESC',
    'PRIVILEGES',
    'USER',
    'USERS',
    'ROLE',
    'ROLES',
    'GRANT',
    'REVOKE',
    'PASSWORD',
    'BOOLEAN',
    'INT32',
    'INT64',
    'FLOAT',
    'DOUBLE',
    'STRING',
    'DATE',
    'TIMESTAMP',
    'BLOB',
    'TEXT',
    'NUMERIC',
    'TAG',
  ];
}

/// 建议类型提示（用于下拉行图标 / 右侧说明）
/// 表提示：word 为裸表名（匹配用），插入内容为 `"库"."表"` 全限定名（REST 无会话状态）
class _TablePrompt extends CodeFieldPrompt {
  final String db;
  final String table;

  _TablePrompt(this.db, this.table)
      : super(
          word: table,
          type: _qualified(db, table),
          customAutocomplete: CodeAutocompleteResult.fromWord(_qualified(db, table)),
        );

  static String _qualified(String db, String table) {
    if (db.isEmpty) return table;
    final d = db.replaceAll('"', '""');
    final t = table.replaceAll('"', '""');
    return '"$d"."$t"';
  }
}

class _ColumnPrompt extends CodeFieldPrompt {
  final TableColumn column;

  _ColumnPrompt(TableColumn c)
      : column = c,
        super(word: c.name, type: c.dataType);
}

enum _SqlContext { none, table, column, dataType }

const _tableKeywords = {
  'FROM', 'JOIN', 'INTO', 'TABLE', 'TABLES', 'UPDATE', 'DELETE',
};

const _columnKeywords = {
  'SELECT', 'WHERE', 'GROUP', 'ORDER', 'BY', 'HAVING', 'SET', 'DESC',
  'ALIGN', 'ON', 'AND', 'OR',
};

const _dataTypeKeywords = {
  'BOOLEAN', 'INT32', 'INT64', 'FLOAT', 'DOUBLE', 'STRING', 'DATE',
  'TIMESTAMP', 'BLOB', 'TEXT', 'NUMERIC', 'COLUMN', 'TIME', 'TAG',
  'ATTRIBUTE', 'FIELD',
};

/// Navicat 风格 SQL 补全：
/// - 大小写不敏感，前缀优先、其次包含
/// - 上下文感知：FROM/JOIN → 表；SELECT/WHERE → 列；别名. / 表. → 该表列；
///   CREATE TABLE / ADD COLUMN → 数据类型
class SqlAutocompletePromptsBuilder implements CodeAutocompletePromptsBuilder {
  final CodeLineEditingController controller;
  final String db;
  final List<String> keywords;
  final List<String> tables;
  final Map<String, List<TableColumn>> columnsByTable;

  SqlAutocompletePromptsBuilder({
    required this.controller,
    SqlAutocompleteData? data,
  })  : db = data?.db ?? '',
        keywords = data?.keywords ?? SqlKeywords.all,
        tables = data?.tables ?? const [],
        columnsByTable = data?.columnsByTable ?? const {};

  @override
  CodeAutocompleteEditingValue? build(
    BuildContext context,
    CodeLine codeLine,
    CodeLineSelection selection,
  ) {
    final lineText = codeLine.text;
    final offset = selection.extentOffset;
    if (_insideStringOrComment(lineText, offset)) {
      return null;
    }

    int start = offset;
    while (start > 0 && _isWordChar(lineText, start - 1)) {
      start--;
    }
    final input = lineText.substring(start, offset);

    final bool member = start > 0 && lineText[start - 1] == '.';
    String memberTarget = '';
    if (member) {
      int s = start - 2;
      while (s >= 0 && (_isWordChar(lineText, s) || lineText[s] == '"')) {
        s--;
      }
      memberTarget = lineText.substring(s + 1, start - 1);
    }

    final textBefore = _textBeforeCursor(selection);
    final sanitized = _sanitize(textBefore);

    if (member) {
      final target = _resolveTable(memberTarget, textBefore);
      final columns = _columnsOf(target);
      if (columns.isEmpty) return null;
      final matched = _rank(columns, input);
      if (matched.isEmpty) return null;
      return CodeAutocompleteEditingValue(input: input, prompts: matched, index: 0);
    }

    final context = _analyzeContext(sanitized);
    final prompts = _buildPrompts(input, context);
    if (prompts.isEmpty) return null;
    return CodeAutocompleteEditingValue(input: input, prompts: prompts, index: 0);
  }

  List<CodePrompt> _buildPrompts(String input, _SqlContext context) {
    if (input.isEmpty) {
      return switch (context) {
        _SqlContext.table => [for (final t in tables) _TablePrompt(db, t)],
        _SqlContext.column => _allColumns(),
        _SqlContext.dataType => _dataTypePrompts(),
        _SqlContext.none => const [],
      };
    }
    return switch (context) {
      _SqlContext.table => [
        ..._rank([for (final t in tables) _TablePrompt(db, t)], input),
        ..._rank(_allColumns(), input),
        ..._rank(_keywordPrompts(), input),
      ],
      _SqlContext.column => [
        ..._rank(_allColumns(), input),
        ..._rank([for (final t in tables) _TablePrompt(db, t)], input),
        ..._rank(_keywordPrompts(), input),
      ],
      _SqlContext.dataType => _rank(_dataTypePrompts(), input),
      _SqlContext.none => [
        ..._rank(_keywordPrompts(), input),
        ..._rank([for (final t in tables) _TablePrompt(db, t)], input),
        ..._rank(_allColumns(), input),
      ],
    };
  }

  List<CodePrompt> _keywordPrompts() =>
      [for (final k in keywords) CodeKeywordPrompt(word: k)];

  List<CodePrompt> _dataTypePrompts() => [
        for (final t in tableDataTypes) CodeKeywordPrompt(word: t.toUpperCase()),
        for (final c in ColumnCategory.values)
          CodeKeywordPrompt(word: c.sqlKeyword),
      ];

  List<CodePrompt> _allColumns() {
    final seen = <String>{};
    final out = <CodePrompt>[];
    for (final cols in columnsByTable.values) {
      for (final c in cols) {
        if (seen.add(c.name.toUpperCase())) {
          out.add(_ColumnPrompt(c));
        }
      }
    }
    return out;
  }

  List<CodePrompt> _columnsOf(String target) {
    var name = target.replaceAll('"', '');
    final dot = name.lastIndexOf('.');
    if (dot >= 0) name = name.substring(dot + 1);
    final lower = name.toLowerCase();
    final found = columnsByTable.entries
        .where((e) => e.key.toLowerCase() == lower)
        .expand((e) => e.value)
        .toList();
    return [for (final c in found) _ColumnPrompt(c)];
  }

  String _resolveTable(String target, String text) {
    final lower = target.toLowerCase();
    final known = columnsByTable.keys.any((k) => k.toLowerCase() == lower);
    if (known) return target;
    final aliases = _parseAliases(text);
    return aliases[lower] ?? target;
  }

  /// 前缀优先、其次包含，大小写不敏感
  List<CodePrompt> _rank(List<CodePrompt> prompts, String input) {
    final u = input.toUpperCase();
    final prefix = <CodePrompt>[];
    final rest = <CodePrompt>[];
    for (final p in prompts) {
      final w = p.word.toUpperCase();
      if (w == u) continue;
      if (w.startsWith(u)) {
        prefix.add(p);
      } else if (w.contains(u)) {
        rest.add(p);
      }
    }
    return [...prefix, ...rest];
  }

  _SqlContext _analyzeContext(String sanitized) {
    if (RegExp(r'CREATE\s+TABLE\b', caseSensitive: false).hasMatch(sanitized)) {
      final open = sanitized.lastIndexOf('(');
      if (open >= 0) return _SqlContext.dataType;
    }
    final toks = _tokenize(sanitized);
    for (var i = toks.length - 1; i >= 0; i--) {
      final t = toks[i];
      if (t is _SymTok) {
        if (t.text == ';') break;
        continue;
      }
      final up = (t as _WordTok).text.toUpperCase();
      if (_tableKeywords.contains(up)) return _SqlContext.table;
      if (_columnKeywords.contains(up)) return _SqlContext.column;
      if (_dataTypeKeywords.contains(up)) return _SqlContext.dataType;
    }
    return _SqlContext.none;
  }

  /// 解析 FROM/JOIN/INTO 之后的表名与可选别名（支持 `FROM t AS a`、`FROM t a`、
  /// 引号标识符 `"db"."t"`）；别名若为 SQL 关键词则忽略
  Map<String, String> _parseAliases(String text) {
    final map = <String, String>{};
    final re = RegExp(
      r'\b(FROM|JOIN|INTO)\s+'
      r'((?:"(?:[^"]|"")*"|\w)+(?:\s*\.\s*(?:"(?:[^"]|"")*"|\w)+)*)'
      r'(?:\s+(?:AS\s+)?(\w+))?',
      caseSensitive: false,
    );
    for (final m in re.allMatches(text)) {
      final tableRaw = m.group(2)!;
      final alias = m.group(3);
      if (alias == null) continue;
      if (_keywordSet.contains(alias.toUpperCase())) continue;
      map[alias.toLowerCase()] = tableRaw;
    }
    return map;
  }

  static const _keywordSet = {
    ..._tableKeywords, ..._columnKeywords, ..._dataTypeKeywords,
  };

  String _textBeforeCursor(CodeLineSelection selection) {
    final lines = controller.value.codeLines;
    if (lines.isEmpty) return '';
    final idx = selection.extentIndex < lines.length
        ? selection.extentIndex
        : lines.length - 1;
    final lineLen = lines[idx].text.length;
    final off = selection.extentOffset > lineLen ? lineLen : selection.extentOffset;
    final sb = StringBuffer();
    for (var i = 0; i < idx; i++) {
      sb.write(lines[i].text);
      sb.write('\n');
    }
    sb.write(lines[idx].text.substring(0, off));
    return sb.toString();
  }
}

bool _isWordChar(String s, int i) {
  final c = s.codeUnitAt(i);
  return (c >= 48 && c <= 57) ||
      (c >= 65 && c <= 90) ||
      (c >= 97 && c <= 122) ||
      c == 95;
}

/// 光标前当前行是否位于字符串 / -- 注释内
bool _insideStringOrComment(String text, int offset) {
  final before = text.substring(0, offset);
  if (before.contains('--')) return true;
  var sq = false;
  var dq = false;
  for (var i = 0; i < before.length; i++) {
    final c = before[i];
    if (c == "'") {
      if (sq && i + 1 < before.length && before[i + 1] == "'") {
        i++;
        continue;
      }
      sq = !sq;
    } else if (c == '"') {
      dq = !dq;
    }
  }
  return sq || dq;
}

String _sanitize(String text) {
  var s = text.replaceAll(RegExp(r'--[^\n]*'), ' ');
  s = s.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), ' ');
  s = s.replaceAll(RegExp(r"'(?:[^']|'')*'"), ' ');
  s = s.replaceAll(RegExp(r'"(?:[^"]|"")*"'), ' ');
  return s;
}

sealed class _Tok {}

class _WordTok extends _Tok {
  final String text;
  _WordTok(this.text);
}

class _SymTok extends _Tok {
  final String text;
  _SymTok(this.text);
}

List<_Tok> _tokenize(String text) {
  final out = <_Tok>[];
  final buf = StringBuffer();
  void flush() {
    if (buf.isNotEmpty) {
      out.add(_WordTok(buf.toString()));
      buf.clear();
    }
  }

  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (_isWordChar(text, i)) {
      buf.write(c);
    } else {
      flush();
      if (c.trim().isNotEmpty) out.add(_SymTok(c));
    }
  }
  flush();
  return out;
}

/// Navicat 风格补全下拉视图
class SqlAutocompleteView extends StatefulWidget implements PreferredSizeWidget {
  static const double _kItemHeight = 28;
  static const double _kMaxHeight = 200;
  static const double _kWidth = 280;

  final ValueNotifier<CodeAutocompleteEditingValue> notifier;
  final ValueChanged<CodeAutocompleteResult> onSelected;
  final SqlAutocompleteController controller;

  const SqlAutocompleteView({
    super.key,
    required this.notifier,
    required this.onSelected,
    required this.controller,
  });

  @override
  Size get preferredSize {
    final n = notifier.value.prompts.length;
    return Size(
      _kWidth,
      math.min(n * _kItemHeight + 8, _kMaxHeight),
    );
  }

  @override
  State<SqlAutocompleteView> createState() => _SqlAutocompleteViewState();
}

class _SqlAutocompleteViewState extends State<SqlAutocompleteView> {
  @override
  void initState() {
    super.initState();
    widget.notifier.addListener(_onChanged);
    widget.controller.opened(widget.notifier.value);
  }

  @override
  void dispose() {
    widget.notifier.removeListener(_onChanged);
    widget.controller.closed();
    super.dispose();
  }

  void _onChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final value = widget.notifier.value;
    final prompts = value.prompts;
    final input = value.input;
    return Container(
      width: SqlAutocompleteView._kWidth,
      constraints: const BoxConstraints(
        maxHeight: SqlAutocompleteView._kMaxHeight,
      ),
      decoration: BoxDecoration(
        color: isLight ? ShadTokens.card : ShadTokens.cardDark,
        borderRadius: BorderRadius.circular(ShadTokens.radiusMedium),
        border: Border.all(
          color: isLight ? ShadTokens.border : ShadTokens.borderDark,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: prompts.length,
        itemBuilder: (context, index) {
          final prompt = prompts[index];
          return _item(
            context,
            prompt,
            index,
            index == value.index,
            input,
            isLight,
          );
        },
      ),
    );
  }

  Widget _item(
    BuildContext context,
    CodePrompt prompt,
    int index,
    bool selected,
    String input,
    bool isLight,
  ) {
    final isColumn = prompt is _ColumnPrompt;
    final icon = _iconFor(prompt);
    final iconColor = _iconColor(prompt, isLight);
    final hint = _hintFor(prompt, isColumn);
    final baseColor =
        isLight ? ShadTokens.foreground : ShadTokens.foregroundDark;
    final hintColor =
        isLight ? ShadTokens.mutedForeground : ShadTokens.mutedForegroundDark;
    return Material(
      color: selected
          ? (isLight ? ShadTokens.muted : ShadTokens.hoverDark)
          : Colors.transparent,
      child: InkWell(
        onTap: () => widget.onSelected(
          widget.notifier.value.copyWith(index: index).autocomplete,
        ),
        child: SizedBox(
          height: SqlAutocompleteView._kItemHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Icon(icon, size: 14, color: iconColor),
                const SizedBox(width: 6),
                Expanded(
                  child: _highlightText(prompt.word, input, baseColor, selected),
                ),
                if (hint.isNotEmpty)
                  Text(
                    hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: hintColor),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _highlightText(
    String word,
    String input,
    Color baseColor,
    bool selected,
  ) {
    const fontSize = 13.0;
    const matchWeight = FontWeight.bold;
    final matchColor = selected
        ? const Color(0xFFFFC107)
        : const Color(0xFF2563EB);
    if (input.isEmpty) {
      return Text(
        word,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: fontSize, color: baseColor),
      );
    }
    final idx = word.toLowerCase().indexOf(input.toLowerCase());
    if (idx < 0) {
      return Text(
        word,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: fontSize, color: baseColor),
      );
    }
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: word.substring(0, idx)),
          TextSpan(
            text: word.substring(idx, idx + input.length),
            style: TextStyle(color: matchColor, fontWeight: matchWeight),
          ),
          TextSpan(text: word.substring(idx + input.length)),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: fontSize, color: baseColor),
    );
  }

  IconData _iconFor(CodePrompt p) {
    if (p is _TablePrompt) return RemixIcons.database_2_line;
    if (p is _ColumnPrompt) {
      return switch (p.column.category) {
        ColumnCategory.time => RemixIcons.calendar_line,
        ColumnCategory.tag => RemixIcons.price_tag_3_line,
        ColumnCategory.attribute => RemixIcons.information_line,
        ColumnCategory.field => RemixIcons.function_line,
      };
    }
    return RemixIcons.hashtag;
  }

  Color _iconColor(CodePrompt p, bool isLight) {
    if (p is _TablePrompt) return const Color(0xFF0F766E);
    if (p is _ColumnPrompt) {
      return isLight ? const Color(0xFF1D4ED8) : const Color(0xFF93C5FD);
    }
    return isLight
        ? ShadTokens.mutedForeground
        : ShadTokens.mutedForegroundDark;
  }

  String _hintFor(CodePrompt p, bool isColumn) {
    if (p is _ColumnPrompt) {
      final dt = p.column.dataType.toUpperCase();
      final cat = p.column.category.label;
      return dt.isEmpty ? cat : '$dt · $cat';
    }
    if (p is _TablePrompt) return p.type;
    return '';
  }
}
