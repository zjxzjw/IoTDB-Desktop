import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/table_meta.dart';
import '../../../core/providers.dart';
import '../../../core/theme/shadcn_tokens.dart';
import '../../../core/utils/sql_builder.dart';
import '../data/database_providers.dart';
import 'column_defs_editor.dart';

/// 建表表单（内嵌于表管理页右侧区域）
class CreateTableForm extends ConsumerStatefulWidget {
  final String db;

  const CreateTableForm({super.key, required this.db});

  @override
  ConsumerState<CreateTableForm> createState() => _CreateTableFormState();
}

class _CreateTableFormState extends ConsumerState<CreateTableForm> {
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
      _exitCreateMode();
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

  void _exitCreateMode() {
    ref.read(createTableModeProvider.notifier).set(false);
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
    return Padding(
      padding: const EdgeInsets.all(ShadTokens.space6),
      child: Form(
        key: _formKey,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _Field(
                      label: '表名 *',
                      child: TextFormField(
                        key: const Key('create-table-name'),
                        controller: _table,
                        decoration: const InputDecoration(isDense: true),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? '请输入表名'
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: ShadTokens.space4),
                  Expanded(
                    child: _Field(
                      label: '表注释（可选）',
                      child: TextFormField(
                        key: const Key('create-table-comment'),
                        controller: _comment,
                        decoration: const InputDecoration(isDense: true),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ShadTokens.space4),
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
              if (_enableTtl) ...[
                const SizedBox(height: ShadTokens.space2),
                _Field(
                  label: 'TTL（毫秒）',
                  child: TextFormField(
                    key: const Key('create-table-ttl'),
                    controller: _ttl,
                    decoration: const InputDecoration(isDense: true),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      return (n == null || n < 1) ? '需为正整数毫秒' : null;
                    },
                  ),
                ),
              ],
              const SizedBox(height: ShadTokens.space6),
              const Text(
                '列定义',
                style: TextStyle(
                  fontSize: ShadTokens.fontBody,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: ShadTokens.space1),
              const Text(
                '时间列（TIME）可不定义，系统自动添加并命名为 time。'
                '标签列/属性列类型固定为 STRING。',
                style: TextStyle(
                  fontSize: 12,
                  color: ShadTokens.mutedForeground,
                ),
              ),
              const SizedBox(height: ShadTokens.space4),
              ColumnDefsEditor(
                onChanged: (cols) => _columns = cols,
              ),
              const SizedBox(height: ShadTokens.space4),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _exitCreateMode,
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

class _Field extends StatelessWidget {
  final String label;
  final Widget child;

  const _Field({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: ShadTokens.space2),
        child,
      ],
    );
  }
}