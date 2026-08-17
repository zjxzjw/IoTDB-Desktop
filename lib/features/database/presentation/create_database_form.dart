import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/providers.dart';
import '../../../core/theme/shadcn_tokens.dart';
import '../../../core/utils/sql_builder.dart';

/// 建库表单（居中 Dialog）：2.0.10 仅支持 4 个建库参数
Future<void> showCreateDatabaseDialog(BuildContext context, WidgetRef ref) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, animation, secondaryAnimation) => Dialog(
      backgroundColor: ShadTokens.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ShadTokens.radiusLarge),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: ShadTokens.space6,
          vertical: ShadTokens.space4,
        ),
        child: const CreateDatabaseDialog(),
      ),
    ),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeIn,
      );
      return ScaleTransition(
        scale: Tween<double>(begin: 0.85, end: 1.0).animate(curved),
        child: FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
            reverseCurve: Curves.easeIn,
          ),
          child: child,
        ),
      );
    },
  );
}

class CreateDatabaseDialog extends ConsumerStatefulWidget {
  const CreateDatabaseDialog({super.key});

  @override
  ConsumerState<CreateDatabaseDialog> createState() =>
      _CreateDatabaseDialogState();
}

class _CreateDatabaseDialogState extends ConsumerState<CreateDatabaseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _ttl = TextEditingController();
  final _partition = TextEditingController();
  final _schemaGroup = TextEditingController();
  final _dataGroup = TextEditingController();

  bool _enableTtl = false;
  bool _ttlInfinite = false;
  bool _submitting = false;

  @override
  void dispose() {
    _name.dispose();
    _ttl.dispose();
    _partition.dispose();
    _schemaGroup.dispose();
    _dataGroup.dispose();
    super.dispose();
  }

  String? _optionalPositiveInt(String? v, String label) {
    if (v == null || v.trim().isEmpty) return null;
    final n = int.tryParse(v.trim());
    return (n == null || n < 1) ? '$label 需为正整数' : null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final sql = SqlBuilder.createDatabase(
        _name.text.trim(),
        ttlMs: _enableTtl ? (_ttlInfinite ? null : (int.tryParse(_ttl.text.trim()) ?? 0)) : null,
        timePartitionIntervalMs: int.tryParse(_partition.text.trim()),
        schemaRegionGroupNum: int.tryParse(_schemaGroup.text.trim()),
        dataRegionGroupNum: int.tryParse(_dataGroup.text.trim()),
      );
      await ref.read(iotdbClientProvider).nonQuery(sql);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('数据库创建成功')));
      ref.invalidate(databaseListProvider);
      final active = ref.read(activeConnectionProvider);
      if (active != null) {
        ref.invalidate(connectionDatabaseListProvider(active));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('创建失败：$e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(RemixIcons.database_2_line, size: 18, color: ShadTokens.primary),
                const SizedBox(width: ShadTokens.space2),
                const Text('新建数据库', style: TextStyle(fontSize: ShadTokens.fontTitle, fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(RemixIcons.close_line, size: 18),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: ShadTokens.space4),
            _LabeledField(
              label: '数据库名 *',
              child: TextFormField(
                controller: _name,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  filled: false,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: ShadTokens.space3,
                    vertical: 12,
                  ),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? '请输入数据库名' : null,
              ),
            ),
            const SizedBox(height: ShadTokens.space4),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('设置 TTL', style: TextStyle(fontSize: 13)),
              value: _enableTtl,
              onChanged: (v) => setState(() => _enableTtl = v ?? false),
            ),
            if (_enableTtl) ...[
              const SizedBox(height: ShadTokens.space2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _LabeledField(
                      label: 'TTL（毫秒）',
                      child: TextFormField(
                        controller: _ttl,
                        enabled: !_ttlInfinite,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          filled: false,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: ShadTokens.space3,
                            vertical: 12,
                          ),
                          hintText: '如：604800000',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (_ttlInfinite) return null;
                          final n = int.tryParse(v ?? '');
                          return (n == null || n < 1) ? '需为正整数毫秒' : null;
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: ShadTokens.space4),
                  _LabeledField(
                    label: '保存时长',
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.tonal(
                        onPressed: () => setState(() => _ttlInfinite = !_ttlInfinite),
                        child: Text(_ttlInfinite ? 'INF（永久）' : 'INF'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: ShadTokens.space4),
            _LabeledField(
              label: '时间分区间隔（毫秒，可选）',
              child: TextFormField(
                controller: _partition,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  filled: false,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: ShadTokens.space3,
                    vertical: 12,
                  ),
                  hintText: '如：86400000',
                ),
                keyboardType: TextInputType.number,
                validator: (v) => _optionalPositiveInt(v, '分区间隔'),
              ),
            ),
            const SizedBox(height: ShadTokens.space4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _LabeledField(
                    label: 'Schema 区域组数（可选）',
                    child: TextFormField(
                      controller: _schemaGroup,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        filled: false,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: ShadTokens.space3,
                          vertical: 12,
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) => _optionalPositiveInt(v, 'Schema 组数'),
                    ),
                  ),
                ),
                const SizedBox(width: ShadTokens.space4),
                Expanded(
                  child: _LabeledField(
                    label: 'Data 区域组数（可选）',
                    child: TextFormField(
                      controller: _dataGroup,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        filled: false,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: ShadTokens.space3,
                          vertical: 12,
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) => _optionalPositiveInt(v, 'Data 组数'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: ShadTokens.space8),
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
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('创建'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 标签在输入框上方的表单字段
class _LabeledField extends StatelessWidget {
  final String label;
  final Widget child;

  const _LabeledField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: ShadTokens.fontAux,
            fontWeight: FontWeight.w500,
            color: ShadTokens.mutedForeground,
          ),
        ),
        const SizedBox(height: ShadTokens.space3),
        child,
      ],
    );
  }
}
