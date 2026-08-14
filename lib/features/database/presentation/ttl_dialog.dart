import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/tdesign_tokens.dart';
import '../../../core/utils/sql_builder.dart';

/// TTL 设置对话框：自定义毫秒 / INF / 取消 TTL
Future<void> showTtlDialog(
  BuildContext context,
  WidgetRef ref, {
  required String database,
}) {
  return showDialog(
    context: context,
    builder: (context) => TtlDialog(database: database),
  );
}

class TtlDialog extends ConsumerStatefulWidget {
  final String database;

  const TtlDialog({super.key, required this.database});

  @override
  ConsumerState<TtlDialog> createState() => _TtlDialogState();
}

enum _TtlMode { custom, infinite, unset }

class _TtlDialogState extends ConsumerState<TtlDialog> {
  _TtlMode _mode = _TtlMode.custom;
  final _ttl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _ttl.dispose();
    super.dispose();
  }

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
      final sql = switch (_mode) {
        _TtlMode.custom => SqlBuilder.setTtl(
          widget.database,
          ttlMs: int.parse(_ttl.text.trim()),
        ),
        _TtlMode.infinite => SqlBuilder.setTtl(widget.database),
        _TtlMode.unset => SqlBuilder.unsetTtl(widget.database),
      };
      await ref.read(iotdbClientProvider).nonQuery(sql);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('TTL 已更新')));
      ref.invalidate(databaseListProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('操作失败：$e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('设置 TTL · ${widget.database}'),
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
                  style: TextStyle(fontSize: TdTokens.fontBody),
                ),
                value: _TtlMode.custom,
              ),
              Padding(
                padding: const EdgeInsets.only(
                  left: 36,
                  bottom: TdTokens.space2,
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
                  style: TextStyle(fontSize: TdTokens.fontBody),
                ),
                value: _TtlMode.infinite,
              ),
              const RadioListTile<_TtlMode>(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '取消 TTL（UNSET）',
                  style: TextStyle(fontSize: TdTokens.fontBody),
                ),
                value: _TtlMode.unset,
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
