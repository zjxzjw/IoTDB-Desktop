import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/models/connection.dart';
import '../../../core/network/iotdb_client.dart';
import '../../../core/providers.dart';
import '../../../core/theme/tdesign_tokens.dart';

/// 新建/编辑连接表单（居中 Dialog）
Future<void> showConnectionFormDialog(
  BuildContext context,
  WidgetRef ref, {
  Connection? editing,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, animation, secondaryAnimation) => Dialog(
      backgroundColor: TdTokens.bgContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TdTokens.radiusLarge),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: TdTokens.space6,
          vertical: TdTokens.space4,
        ),
        child: ConnectionFormDialog(editing: editing),
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

class ConnectionFormDialog extends ConsumerStatefulWidget {
  final Connection? editing;

  const ConnectionFormDialog({super.key, this.editing});

  @override
  ConsumerState<ConnectionFormDialog> createState() =>
      _ConnectionFormDialogState();
}

class _ConnectionFormDialogState extends ConsumerState<ConnectionFormDialog> {
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
          constraints: const BoxConstraints(maxWidth: 560),
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
              const SizedBox(height: TdTokens.space4),
              _LabeledField(
                label: '连接名称 *',
                child: TextFormField(
                  controller: _name,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    filled: false,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: TdTokens.space3,
                      vertical: 12,
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? '请输入连接名称' : null,
                ),
              ),
              const SizedBox(height: TdTokens.space4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _LabeledField(
                      label: '主机地址 *',
                      child: TextFormField(
                        controller: _host,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          filled: false,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: TdTokens.space3,
                            vertical: 12,
                          ),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? '请输入主机地址'
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: TdTokens.space4),
                  _LabeledField(
                    label: 'REST 端口 *',
                    child: SizedBox(
                      width: 140,
                      child: TextFormField(
                        controller: _port,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          filled: false,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: TdTokens.space3,
                            vertical: 12,
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          final p = int.tryParse(v ?? '');
                          return (p == null || p < 1 || p > 65535)
                              ? '1-65535'
                              : null;
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: TdTokens.space4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _LabeledField(
                      label: '用户名',
                      child: TextFormField(
                        controller: _username,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          filled: false,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: TdTokens.space3,
                            vertical: 12,
                          ),
                          hintText: 'root',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: TdTokens.space4),
                  Expanded(
                    child: _LabeledField(
                      label: '密码',
                      child: TextFormField(
                        controller: _password,
                        style: const TextStyle(fontSize: 13),
                        obscureText: true,
                        decoration: InputDecoration(
                          filled: false,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: TdTokens.space3,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: TdTokens.space4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _LabeledField(
                      label: '超时（毫秒）',
                      child: TextFormField(
                        controller: _timeout,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          filled: false,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: TdTokens.space3,
                            vertical: 12,
                          ),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ),
                  const SizedBox(width: TdTokens.space4),
                  Expanded(
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      hoverColor: Colors.transparent,
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      hoverColor: Colors.transparent,
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
                    _LabeledField(
                      label: 'row_limit',
                      child: SizedBox(
                        width: 150,
                        child: TextFormField(
                          controller: _rowLimit,
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            filled: false,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: TdTokens.space3,
                              vertical: 12,
                            ),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: TdTokens.space4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
            ],
          ),
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
            fontSize: TdTokens.fontAux,
            fontWeight: FontWeight.w500,
            color: TdTokens.textSecondary,
          ),
        ),
        const SizedBox(height: TdTokens.space3),
        child,
      ],
    );
  }
}
