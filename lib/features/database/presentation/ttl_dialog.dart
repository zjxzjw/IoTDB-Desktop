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
        width: 400,
        child: RadioGroup<_TtlMode>(
          groupValue: _mode,
          onChanged: (v) => setState(() => _mode = v!),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const RadioListTile<_TtlMode>(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '自定义 TTL',
                  style: TextStyle(fontSize: ShadTokens.fontBody),
                ),
                value: _TtlMode.custom,
              ),
              Padding(
                padding: const EdgeInsets.only(
                  left: 36,
                  bottom: ShadTokens.space2,
                ),
                child: TextField(
                  controller: _ttl,
                  enabled: _mode == _TtlMode.custom,
                  decoration: const InputDecoration(
                    labelText: 'TTL（毫秒）',
                    hintText: '如：604800000（7 天）',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const RadioListTile<_TtlMode>(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '永久保存（INF）',
                  style: TextStyle(fontSize: ShadTokens.fontBody),
                ),
                value: _TtlMode.infinite,
              ),
              if (isTable)
                const RadioListTile<_TtlMode>(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '恢复数据库默认 TTL',
                    style: TextStyle(fontSize: ShadTokens.fontBody),
                  ),
                  value: _TtlMode.defaultTtl,
                ),
            ],
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
