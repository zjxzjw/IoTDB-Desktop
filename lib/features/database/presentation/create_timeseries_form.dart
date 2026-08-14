import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/providers.dart';
import '../../../core/theme/shadcn_tokens.dart';
import '../../../core/utils/sql_builder.dart';
import '../data/database_providers.dart';

const List<String> kDataTypes = [
  'BOOLEAN', 'INT32', 'INT64', 'FLOAT', 'DOUBLE', 'TEXT', 'STRING', 'BLOB', 'TIMESTAMP', 'DATE',
];

const List<String> kEncodings = [
  'PLAIN', 'RLE', 'TS_2DIFF', 'GORILLA', 'DICTIONARY', 'FREQ', 'ZIGZAG', 'REGULAR',
];

const List<String> kCompressors = [
  'SNAPPY', 'GZIP', 'LZ4', 'ZSTD', 'UNCOMPRESSED',
];

/// 建测点表单（ModalBottomSheet），[devicePrefix] 为所选设备路径
Future<void> showCreateTimeseriesSheet(BuildContext context, WidgetRef ref, {String? devicePrefix}) {
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
      child: CreateTimeseriesSheet(devicePrefix: devicePrefix),
    ),
  );
}

class CreateTimeseriesSheet extends ConsumerStatefulWidget {
  final String? devicePrefix;

  const CreateTimeseriesSheet({super.key, this.devicePrefix});

  @override
  ConsumerState<CreateTimeseriesSheet> createState() => _CreateTimeseriesSheetState();
}

class _CreateTimeseriesSheetState extends ConsumerState<CreateTimeseriesSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _device;
  final _name = TextEditingController();
  final _tags = TextEditingController();
  final _attrs = TextEditingController();

  String _dataType = 'FLOAT';
  String _encoding = '';
  String _compressor = 'SNAPPY';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _device = TextEditingController(text: widget.devicePrefix ?? '');
  }

  @override
  void dispose() {
    _device.dispose();
    _name.dispose();
    _tags.dispose();
    _attrs.dispose();
    super.dispose();
  }

  Map<String, String> _parseKv(String text) {
    final map = <String, String>{};
    for (final part in text.split(',')) {
      final kv = part.trim();
      if (kv.isEmpty) continue;
      final idx = kv.indexOf('=');
      if (idx <= 0) continue;
      map[kv.substring(0, idx).trim()] = kv.substring(idx + 1).trim().replaceAll(RegExp(r"^'|'$"), '');
    }
    return map;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final device = _device.text.trim();
      final name = _name.text.trim();
      final path = name.contains('.') && name.startsWith('root')
          ? name
          : (device.endsWith('.') ? '$device$name' : '$device.$name');
      final sql = SqlBuilder.createTimeseries(
        path,
        dataType: _dataType,
        encoding: _encoding,
        compressor: _compressor,
        tags: _parseKv(_tags.text),
        attributes: _parseKv(_attrs.text),
      );
      await ref.read(iotdbClientProvider).nonQuery(sql);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('测点创建成功')));
      ref.invalidate(timeseriesListProvider(device));
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
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(RemixIcons.add_circle_line, size: 18, color: ShadTokens.primary),
                  const SizedBox(width: ShadTokens.space2),
                  const Text('新建测点', style: TextStyle(fontSize: ShadTokens.fontTitle, fontWeight: FontWeight.w600)),
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
                controller: _device,
                decoration: const InputDecoration(labelText: '设备路径 *', hintText: '如：root.test.d1'),
                validator: (v) => (v == null || v.trim().isEmpty) ? '请输入设备路径' : null,
              ),
              const SizedBox(height: ShadTokens.space3),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: '测点名 *', hintText: '如：temperature 或 sub.temp'),
                validator: (v) => (v == null || v.trim().isEmpty) ? '请输入测点名' : null,
              ),
              const SizedBox(height: ShadTokens.space3),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _dataType,
                      decoration: const InputDecoration(labelText: '数据类型 *'),
                      items: [for (final t in kDataTypes) DropdownMenuItem(value: t, child: Text(t))],
                      onChanged: (v) => setState(() => _dataType = v ?? 'FLOAT'),
                    ),
                  ),
                  const SizedBox(width: ShadTokens.space3),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: null,
                      decoration: const InputDecoration(labelText: '编码（默认）'),
                      items: [for (final e in kEncodings) DropdownMenuItem(value: e, child: Text(e))],
                      onChanged: (v) => setState(() => _encoding = v ?? ''),
                    ),
                  ),
                  const SizedBox(width: ShadTokens.space3),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _compressor,
                      decoration: const InputDecoration(labelText: '压缩 *'),
                      items: [for (final c in kCompressors) DropdownMenuItem(value: c, child: Text(c))],
                      onChanged: (v) => setState(() => _compressor = v ?? 'SNAPPY'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ShadTokens.space3),
              TextFormField(
                controller: _tags,
                decoration: const InputDecoration(
                  labelText: '标签（可选，key=value, key2=value2）',
                  hintText: '如：unit=Celsius, location=hall1',
                ),
              ),
              const SizedBox(height: ShadTokens.space3),
              TextFormField(
                controller: _attrs,
                decoration: const InputDecoration(
                  labelText: '属性（可选，key=value, key2=value2）',
                  hintText: '如：description=室内温度',
                ),
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