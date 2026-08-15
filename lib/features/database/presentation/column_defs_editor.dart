import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';
import 'package:uuid/uuid.dart';

import '../../../core/models/table_meta.dart';
import '../../../core/theme/shadcn_tokens.dart';

/// 表结构列定义编辑器（建表 / 加列复用）
///
/// 每行编辑一列：列名 / 类别 / 数据类型 / 注释。
/// 类别联动规则（表模型约束）：
/// - TIME      → 数据类型固定 TIMESTAMP
/// - TAG / ATTRIBUTE → 数据类型固定 STRING
/// - FIELD     → 可选任意数据类型
class ColumnDefsEditor extends StatefulWidget {
  /// 行内容变化回调（仅含列名非空的有效行）
  final ValueChanged<List<TableColumn>> onChanged;

  /// 是否允许新增/编辑时间列（建表允许，加列不允许）
  final bool allowTimeCategory;

  const ColumnDefsEditor({
    super.key,
    required this.onChanged,
    this.allowTimeCategory = true,
  });

  @override
  State<ColumnDefsEditor> createState() => _ColumnDefsEditorState();
}

class _RowData {
  final String id;
  TableColumn? column;

  _RowData() : id = const Uuid().v4();
}

class _ColumnDefsEditorState extends State<ColumnDefsEditor> {
  final List<_RowData> _rows = [_RowData()];

  void _emit() {
    widget.onChanged([
      for (final r in _rows)
        if (r.column != null) r.column!,
    ]);
  }

  void _add() {
    setState(() => _rows.add(_RowData()));
    _emit();
  }

  void _remove(int index) {
    setState(() => _rows.removeAt(index));
    _emit();
  }

  void _update(int index, TableColumn? column) {
    _rows[index].column = column;
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < _rows.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: ShadTokens.space2),
            child: _ColumnRow(
              key: ValueKey(_rows[i].id),
              initial: _rows[i].column,
              allowTimeCategory: widget.allowTimeCategory,
              showRemove: _rows.length > 1,
              onChanged: (col) => _update(i, col),
              onRemove: _rows.length > 1 ? () => _remove(i) : null,
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _add,
            icon: const Icon(RemixIcons.add_line, size: 15),
            label: const Text('添加列'),
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: ShadTokens.space3),
            ),
          ),
        ),
      ],
    );
  }
}

class _ColumnRow extends StatefulWidget {
  final TableColumn? initial;
  final bool allowTimeCategory;
  final bool showRemove;
  final ValueChanged<TableColumn?> onChanged;
  final VoidCallback? onRemove;

  const _ColumnRow({
    super.key,
    this.initial,
    required this.allowTimeCategory,
    required this.showRemove,
    required this.onChanged,
    this.onRemove,
  });

  @override
  State<_ColumnRow> createState() => _ColumnRowState();
}

class _ColumnRowState extends State<_ColumnRow> {
  late final TextEditingController _name;
  late final TextEditingController _comment;
  late ColumnCategory _category;
  String _fieldType = 'DOUBLE';

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    _name = TextEditingController(text: init?.name ?? '');
    _comment = TextEditingController(text: init?.comment ?? '');
    _category = init?.category ?? ColumnCategory.field;
    if (_category == ColumnCategory.field) {
      _fieldType = init?.dataType.isNotEmpty == true ? init!.dataType : 'DOUBLE';
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _comment.dispose();
    super.dispose();
  }

  List<ColumnCategory> get _categories => [
    if (widget.allowTimeCategory) ColumnCategory.time,
    ColumnCategory.tag,
    ColumnCategory.attribute,
    ColumnCategory.field,
  ];

  String get _effectiveType => switch (_category) {
    ColumnCategory.time => 'TIMESTAMP',
    ColumnCategory.tag => 'STRING',
    ColumnCategory.attribute => 'STRING',
    ColumnCategory.field => _fieldType,
  };

  TableColumn? get _value {
    final name = _name.text.trim();
    if (name.isEmpty) return null;
    final comment = _comment.text.trim();
    return TableColumn(
      name: name,
      dataType: _effectiveType,
      category: _category,
      comment: comment.isEmpty ? null : comment,
    );
  }

  void _emit() => widget.onChanged(_value);

  @override
  Widget build(BuildContext context) {
    final fixedType = _category != ColumnCategory.field;
    return Container(
      padding: const EdgeInsets.all(ShadTokens.space3),
      decoration: BoxDecoration(
        border: Border.all(color: ShadTokens.border),
        borderRadius: BorderRadius.circular(ShadTokens.radiusDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _name,
                  onChanged: (_) => _emit(),
                  decoration: const InputDecoration(
                    labelText: '列名 *',
                    hintText: '如：temperature',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: ShadTokens.space2),
              DropdownButton<ColumnCategory>(
                value: _category,
                isDense: true,
                underline: const SizedBox.shrink(),
                style: const TextStyle(fontSize: 13, color: ShadTokens.foreground),
                items: [
                  for (final c in _categories)
                    DropdownMenuItem(value: c, child: Text(c.label)),
                ],
                onChanged: (c) {
                  if (c == null) return;
                  setState(() => _category = c);
                  _emit();
                },
              ),
              const SizedBox(width: ShadTokens.space2),
              SizedBox(
                width: 130,
                child: fixedType
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: ShadTokens.space2,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: ShadTokens.muted,
                          borderRadius: BorderRadius.circular(ShadTokens.radiusDefault),
                        ),
                        child: Text(
                          _effectiveType,
                          style: const TextStyle(
                            fontSize: 13,
                            color: ShadTokens.mutedForeground,
                          ),
                        ),
                      )
                    : DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _fieldType,
                          isDense: true,
                          isExpanded: true,
                          style: const TextStyle(
                            fontSize: 13,
                            color: ShadTokens.foreground,
                          ),
                          items: [
                            for (final t in tableDataTypes)
                              DropdownMenuItem(value: t, child: Text(t)),
                          ],
                          onChanged: (t) {
                            if (t == null) return;
                            setState(() => _fieldType = t);
                            _emit();
                          },
                        ),
                      ),
              ),
              if (widget.showRemove)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: '删除该列',
                  onPressed: widget.onRemove,
                  icon: const Icon(
                    RemixIcons.delete_bin_line,
                    size: 16,
                    color: ShadTokens.destructive,
                  ),
                ),
            ],
          ),
          const SizedBox(height: ShadTokens.space2),
          TextField(
            controller: _comment,
            onChanged: (_) => _emit(),
            decoration: const InputDecoration(
              labelText: '列注释（可选）',
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }
}
