import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/models/table_meta.dart';
import '../../../core/providers.dart';
import '../../../core/theme/shadcn_tokens.dart';
import '../../../core/utils/sql_builder.dart';
import '../data/database_providers.dart';
import 'column_defs_editor.dart';

/// 建表表单（ModalBottomSheet）
Future<void> showCreateTableSheet(
  BuildContext context,
  WidgetRef ref, {
  required String db,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: ShadTokens.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(ShadTokens.radiusLarge),
      ),
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        left: ShadTokens.space6,
        right: ShadTokens.space6,
        top: ShadTokens.space4,
        bottom: MediaQuery.of(context).viewInsets.bottom + ShadTokens.space6,
      ),
      child: CreateTableSheet(db: db),
    ),
  );
}

class CreateTableSheet extends ConsumerStatefulWidget {
  final String db;

  const CreateTableSheet({super.key, required this.db});

  @override
  ConsumerState<CreateTableSheet> createState() => _CreateTableSheetState();
}

class _CreateTableSheetState extends ConsumerState<CreateTableSheet> {
  final _formKey = GlobalKey<FormState>();
  final _table = TextEditingController();
  final _comment = TextEditingController();
  final _ttl = TextEditingController();
  bool _enableTtl = false;
  bool _submitting = false;
  List<TableColumn> _columns = [];

  @override
  void dispose() {
    _table.dispose();
    _comment.dispose();
    _ttl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final timeCount =
        _columns.where((c) => c.category == ColumnCategory.time).length;
    if (timeCount > 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('最多只能定义一个时间列（TIME）')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final sql = SqlBuilder.createTable(
        widget.db,
        _table.text.trim(),
        columns: _columns,
        comment: _comment.text.trim().isEmpty ? null : _comment.text.trim(),
        ttlMs: _enableTtl ? (int.tryParse(_ttl.text.trim()) ?? 0) : null,
      );
      await ref.read(iotdbClientProvider).nonQuery(sql);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('表创建成功')),
      );
      _invalidateSchema();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('创建失败：$e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _invalidateSchema() {
    ref.invalidate(tableListProvider(widget.db));
    final conn = ref.read(activeConnectionProvider);
    if (conn != null) {
      ref.invalidate(connectionTableListProvider(TableScope(conn, widget.db)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(
                    RemixIcons.table_line,
                    size: 18,
                    color: ShadTokens.primary,
                  ),
                  const SizedBox(width: ShadTokens.space2),
                  const Text(
                    '新建表',
                    style: TextStyle(
                      fontSize: ShadTokens.fontTitle,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(RemixIcons.close_line, size: 18),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: ShadTokens.space3),
              Text('数据库：${widget.db}',
                style: const TextStyle(
                  fontSize: 13,
                  color: ShadTokens.mutedForeground,
                ),
              ),
              const SizedBox(height: ShadTokens.space3),
              TextFormField(
                controller: _table,
                decoration: const InputDecoration(
                  labelText: '表名 *',
                  hintText: '如：wind_turbine',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '请输入表名' : null,
              ),
              const SizedBox(height: ShadTokens.space3),
              TextFormField(
                controller: _comment,
                decoration: const InputDecoration(
                  labelText: '表注释（可选）',
                  hintText: '对该类设备的说明',
                ),
              ),
              const SizedBox(height: ShadTokens.space2),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text(
                  '设置表 TTL（可选，默认继承数据库 TTL）',
                  style: TextStyle(fontSize: 13),
                ),
                value: _enableTtl,
                onChanged: (v) => setState(() => _enableTtl = v ?? false),
              ),
              if (_enableTtl)
                TextFormField(
                  controller: _ttl,
                  decoration: const InputDecoration(
                    labelText: 'TTL（毫秒）',
                    hintText: '如：604800000（7 天）',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    return (n == null || n < 1) ? '需为正整数毫秒' : null;
                  },
                ),
              const SizedBox(height: ShadTokens.space4),
              const Text(
                '列定义',
                style: TextStyle(
                  fontSize: ShadTokens.fontBody,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: ShadTokens.space2),
              const Text(
                '时间列（TIME）可不定义，系统自动添加并命名为 time。'
                '标签列/属性列类型固定为 STRING。',
                style: TextStyle(
                  fontSize: 12,
                  color: ShadTokens.mutedForeground,
                ),
              ),
              const SizedBox(height: ShadTokens.space3),
              ColumnDefsEditor(
                onChanged: (cols) => _columns = cols,
              ),
              const SizedBox(height: ShadTokens.space4),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: ShadTokens.space2),
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('创建'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
