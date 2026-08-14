import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/providers.dart';
import '../../../core/theme/shadcn_tokens.dart';
import '../../../core/utils/sql_builder.dart';

/// 建库表单（ModalBottomSheet）：2.0.10 仅支持 4 个建库参数
Future<void> showCreateDatabaseSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: ShadTokens.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(ShadTokens.radiusLarge)),
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        left: ShadTokens.space6,
        right: ShadTokens.space6,
        top: ShadTokens.space4,
        bottom: MediaQuery.of(context).viewInsets.bottom + ShadTokens.space6,
      ),
      child: const CreateDatabaseSheet(),
    ),
  );
}

class CreateDatabaseSheet extends ConsumerStatefulWidget {
  const CreateDatabaseSheet({super.key});

  @override
  ConsumerState<CreateDatabaseSheet> createState() => _CreateDatabaseSheetState();
}

class _CreateDatabaseSheetState extends ConsumerState<CreateDatabaseSheet> {
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
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
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
              const SizedBox(height: ShadTokens.space3),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: '数据库名 *', hintText: '如：root.test 或 test'),
                validator: (v) => (v == null || v.trim().isEmpty) ? '请输入数据库名' : null,
              ),
              const SizedBox(height: ShadTokens.space3),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('设置 TTL', style: TextStyle(fontSize: 13)),
                value: _enableTtl,
                onChanged: (v) => setState(() => _enableTtl = v ?? false),
              ),
              if (_enableTtl) ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _ttl,
                        enabled: !_ttlInfinite,
                        decoration: const InputDecoration(labelText: 'TTL（毫秒）', hintText: '如：604800000'),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (_ttlInfinite) return null;
                          final n = int.tryParse(v ?? '');
                          return (n == null || n < 1) ? '需为正整数毫秒' : null;
                        },
                      ),
                    ),
                    const SizedBox(width: ShadTokens.space2),
                    const Text('或', style: TextStyle(fontSize: 12, color: ShadTokens.mutedForeground)),
                    const SizedBox(width: ShadTokens.space2),
                    FilledButton.tonal(
                      onPressed: () => setState(() => _ttlInfinite = !_ttlInfinite),
                      child: Text(_ttlInfinite ? 'INF（永久）' : 'INF'),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: ShadTokens.space3),
              TextFormField(
                controller: _partition,
                decoration: const InputDecoration(
                  labelText: 'TIME_PARTITION_INTERVAL（毫秒，可选）',
                  hintText: '如：86400000',
                ),
                keyboardType: TextInputType.number,
                validator: (v) => _optionalPositiveInt(v, '分区间隔'),
              ),
              const SizedBox(height: ShadTokens.space3),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _schemaGroup,
                      decoration: const InputDecoration(labelText: 'SCHEMA_REGION_GROUP_NUM（可选）'),
                      keyboardType: TextInputType.number,
                      validator: (v) => _optionalPositiveInt(v, 'Schema 组数'),
                    ),
                  ),
                  const SizedBox(width: ShadTokens.space3),
                  Expanded(
                    child: TextFormField(
                      controller: _dataGroup,
                      decoration: const InputDecoration(labelText: 'DATA_REGION_GROUP_NUM（可选）'),
                      keyboardType: TextInputType.number,
                      validator: (v) => _optionalPositiveInt(v, 'Data 组数'),
                    ),
                  ),
                ],
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
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
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
