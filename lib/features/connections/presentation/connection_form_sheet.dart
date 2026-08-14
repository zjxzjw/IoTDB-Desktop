import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/models/connection.dart';
import '../../../core/network/iotdb_client.dart';
import '../../../core/providers.dart';
import '../../../core/theme/tdesign_tokens.dart';

/// 新建/编辑连接表单（ModalBottomSheet）
Future<void> showConnectionFormSheet(
  BuildContext context,
  WidgetRef ref, {
  Connection? editing,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: TdTokens.bgContainer,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(TdTokens.radiusLarge),
      ),
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        left: TdTokens.space6,
        right: TdTokens.space6,
        top: TdTokens.space4,
        bottom: MediaQuery.of(context).viewInsets.bottom + TdTokens.space6,
      ),
      child: ConnectionFormSheet(editing: editing),
    ),
  );
}

class ConnectionFormSheet extends ConsumerStatefulWidget {
  final Connection? editing;

  const ConnectionFormSheet({super.key, this.editing});

  @override
  ConsumerState<ConnectionFormSheet> createState() =>
      _ConnectionFormSheetState();
}

class _ConnectionFormSheetState extends ConsumerState<ConnectionFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _host;
  late final TextEditingController _port;
  late final TextEditingController _username;
  late final TextEditingController _password;
  late final TextEditingController _timeout;
  late final TextEditingController _rowLimit;

  bool _enableSSL = false;
  bool _useRowLimit = false;
  bool _saving = false;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    final c = widget.editing;
    _name = TextEditingController(text: c?.name ?? '');
    _host = TextEditingController(text: c?.host ?? '');
    _port = TextEditingController(text: (c?.port ?? 18080).toString());
    _username = TextEditingController(text: c?.username ?? 'root');
    _password = TextEditingController(text: c?.password ?? '');
    _timeout = TextEditingController(text: (c?.timeoutMs ?? 30000).toString());
    _rowLimit = TextEditingController();
    _enableSSL = c?.enableSSL ?? false;
    _useRowLimit = (c?.rowLimit ?? 0) > 0;
    _rowLimit.text = (c?.rowLimit ?? 10000).toString();
  }

  @override
  void dispose() {
    _name.dispose();
    _host.dispose();
    _port.dispose();
    _username.dispose();
    _password.dispose();
    _timeout.dispose();
    _rowLimit.dispose();
    super.dispose();
  }

  Connection? _buildConnection() {
    if (!_formKey.currentState!.validate()) return null;
    final port = int.tryParse(_port.text.trim()) ?? 0;
    final timeout = int.tryParse(_timeout.text.trim()) ?? 30000;
    return Connection(
      id: widget.editing?.id ?? '',
      name: _name.text.trim(),
      host: _host.text.trim(),
      port: port,
      username: _username.text.trim(),
      password: _password.text,
      enableSSL: _enableSSL,
      timeoutMs: timeout,
      rowLimit: _useRowLimit
          ? (int.tryParse(_rowLimit.text.trim()) ?? 10000)
          : null,
      createdAt: widget.editing?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Future<void> _test() async {
    final conn = _buildConnection();
    if (conn == null) return;
    setState(() => _testing = true);
    try {
      final client = IotdbClient(conn);
      final ms = await client.ping();
      String version = '';
      try {
        final r = await client.query('SHOW VERSION');
        version = r.rows.isNotEmpty ? '${r.rows.first.first}' : '';
      } catch (_) {}
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '连接成功（${ms}ms）${version.isEmpty ? '' : '，服务端版本 $version'}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _save() async {
    final conn = _buildConnection();
    if (conn == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(connectionStoreProvider.notifier).save(conn);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.editing == null ? '连接已保存' : '连接已更新')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('保存失败：$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
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
                  const Icon(
                    RemixIcons.link_m,
                    size: 18,
                    color: TdTokens.brand,
                  ),
                  const SizedBox(width: TdTokens.space2),
                  Text(
                    widget.editing == null ? '新建连接' : '编辑连接',
                    style: const TextStyle(
                      fontSize: TdTokens.fontTitle,
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
              const SizedBox(height: TdTokens.space3),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: '连接名称 *',
                  hintText: '如：生产环境 1C1D',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '请输入连接名称' : null,
              ),
              const SizedBox(height: TdTokens.space3),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _host,
                      decoration: const InputDecoration(
                        labelText: '主机地址 *',
                        hintText: '106.55.231.32',
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? '请输入主机地址' : null,
                    ),
                  ),
                  const SizedBox(width: TdTokens.space3),
                  SizedBox(
                    width: 140,
                    child: TextFormField(
                      controller: _port,
                      decoration: const InputDecoration(labelText: 'REST 端口 *'),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final p = int.tryParse(v ?? '');
                        return (p == null || p < 1 || p > 65535)
                            ? '1-65535'
                            : null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: TdTokens.space3),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _username,
                      decoration: const InputDecoration(
                        labelText: '用户名',
                        hintText: 'root',
                      ),
                    ),
                  ),
                  const SizedBox(width: TdTokens.space3),
                  Expanded(
                    child: TextFormField(
                      controller: _password,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: '密码',
                        hintText: '存于系统钥匙串',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: TdTokens.space3),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _timeout,
                      decoration: const InputDecoration(labelText: '超时（毫秒）'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: TdTokens.space3),
                  Expanded(
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'HTTPS',
                        style: TextStyle(fontSize: 13),
                      ),
                      value: _enableSSL,
                      onChanged: (v) => setState(() => _enableSSL = v),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        '自定义行数上限',
                        style: TextStyle(fontSize: 13),
                      ),
                      value: _useRowLimit,
                      onChanged: (v) =>
                          setState(() => _useRowLimit = v ?? false),
                    ),
                  ),
                  if (_useRowLimit)
                    SizedBox(
                      width: 150,
                      child: TextFormField(
                        controller: _rowLimit,
                        decoration: const InputDecoration(
                          labelText: 'row_limit',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: TdTokens.space4),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _testing ? null : _test,
                    child: _testing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('测试连接'),
                  ),
                  const SizedBox(width: TdTokens.space2),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: TdTokens.space2),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('保存'),
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
