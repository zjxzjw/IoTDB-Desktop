import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/shadcn_tokens.dart';
import '../../../core/utils/sql_builder.dart';
import '../data/database_providers.dart';

/// TTL 目标类型：数据库 / 表
enum TtlTarget { database, table }

/// TTL 设置对话框：自定义毫秒 / INF（永久） / 恢复数据库默认（仅表）
Future<void> showTtlDialog(
  BuildContext context,
  WidgetRef ref, {
  required TtlTarget target,
  required String db,
  String? table,
}) {
  return showDialog(
    context: context,
    builder: (context) => TtlDialog(target: target, db: db, table: table),
  );
}

class TtlDialog extends ConsumerStatefulWidget {
  final TtlTarget target;
  final String db;
  final String? table;

  const TtlDialog({
    super.key,
    required this.target,
    required this.db,
    this.table,
  });

  @override
  ConsumerState<TtlDialog> createState() => _TtlDialogState();
}

enum _TtlMode { custom, infinite, defaultTtl }

class _TtlDialogState extends ConsumerState<TtlDialog> {
  _TtlMode _mode = _TtlMode.custom;
  final _ttl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _ttl.dispose();
    super.dispose();
  }

  String get _title => switch (widget.target) {
    TtlTarget.database => '设置数据库 TTL · ${widget.db}',
    TtlTarget.table => '设置表 TTL · ${widget.db}.${widget.table}',
  };

  Future<void> _submit() async {
    if (_mode == _TtlMode.custom) {
      final n = int.tryParse(_ttl.text.trim());
      if (n == null || n < 1) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('TTL 需为正整数毫秒')));
        return;
      }
    }
    setState(() => _submitting = true);
    try {
      final sql = switch (widget.target) {
        TtlTarget.database => switch (_mode) {
          _TtlMode.custom => SqlBuilder.alterDatabaseTtl(
            widget.db,
            ttlMs: int.parse(_ttl.text.trim()),
          ),
          _TtlMode.infinite => SqlBuilder.alterDatabaseTtl(widget.db),
          _TtlMode.defaultTtl => SqlBuilder.alterDatabaseTtl(widget.db),
        },
        TtlTarget.table => switch (_mode) {
          _TtlMode.custom => SqlBuilder.alterTableTtl(
            widget.db,
            widget.table!,
            ttlMs: int.parse(_ttl.text.trim()),
          ),
          _TtlMode.infinite => SqlBuilder.alterTableTtl(widget.db, widget.table!),
          _TtlMode.defaultTtl => SqlBuilder.alterTableTtl(
            widget.db,
            widget.table!,
            useDefault: true,
          ),
        },
      };
      await ref.read(iotdbClientProvider).nonQuery(sql);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('TTL 已更新')));
      _invalidate();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('操作失败：$e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _invalidate() {
    ref.invalidate(databaseListProvider);
    ref.invalidate(tableListProvider(widget.db));
    final conn = ref.read(activeConnectionProvider);
    if (conn != null) {
      ref.invalidate(connectionTableListProvider(TableScope(conn, widget.db)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTable = widget.target == TtlTarget.table;
    return AlertDialog(
      title: Text(_title),
      content: SizedBox(
        width: 440,
        child: RadioGroup<_TtlMode>(
          groupValue: _mode,
          onChanged: (v) => setState(() => _mode = v!),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: ShadTokens.divider),
              borderRadius: BorderRadius.circular(ShadTokens.radiusDefault),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: ShadTokens.space3,
              vertical: ShadTokens.space1,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RadioListTile<_TtlMode>(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text(
                    '自定义 TTL',
                    style: TextStyle(fontSize: ShadTokens.fontBody),
                  ),
                  secondary: SizedBox(
                    width: 200,
                    child: TextField(
                      controller: _ttl,
                      enabled: _mode == _TtlMode.custom,
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: ShadTokens.space3,
                          vertical: 10,
                        ),
                        hintText: '毫秒，如：604800000',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  value: _TtlMode.custom,
                ),
                const Divider(height: 1, color: ShadTokens.divider),
                RadioListTile<_TtlMode>(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text(
                    '永久保存（INF）',
                    style: TextStyle(fontSize: ShadTokens.fontBody),
                  ),
                  value: _TtlMode.infinite,
                ),
                if (isTable) ...[
                  const Divider(height: 1, color: ShadTokens.divider),
                  RadioListTile<_TtlMode>(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text(
                      '恢复数据库默认 TTL',
                      style: TextStyle(fontSize: ShadTokens.fontBody),
                    ),
                    value: _TtlMode.defaultTtl,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
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
              : const Text('确定'),
        ),
      ],
    );
  }
}
