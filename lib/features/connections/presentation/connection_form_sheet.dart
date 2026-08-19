import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/models/connection.dart';
import '../../../core/network/iotdb_client.dart';
import '../../../core/providers.dart';
import '../../../core/theme/shadcn_tokens.dart';

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
      backgroundColor: ShadTokens.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ShadTokens.radiusLarge),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: ShadTokens.space6,
          vertical: ShadTokens.space4,
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
  String? _testError;
  String? _testSuccess;

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
    setState(() {
      _testing = true;
      _testError = null;
      _testSuccess = null;
    });
    try {
      final client = IotdbClient(conn);
      final ms = await client.ping();
      String version = '';
      try {
        final r = await client.query('SHOW VERSION');
        version = r.rows.isNotEmpty ? '${r.rows.first.first}' : '';
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _testSuccess =
            '连接成功（${ms}ms）${version.isEmpty ? '' : '，服务端版本 $version'}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _testError = '$e');
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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('保存失败：$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// 测试连接结果提示条：仅在出错/成功时显示，无消息则返回空。
  Widget _buildMessageBar() {
    if (_testError == null && _testSuccess == null) {
      return const SizedBox.shrink();
    }
    if (_testError != null) {
      return Container(
        padding: const EdgeInsets.all(ShadTokens.space3),
        decoration: BoxDecoration(
          color: ShadTokens.destructive.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(ShadTokens.radiusDefault),
          border: Border.all(
            color: ShadTokens.destructive.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  RemixIcons.error_warning_line,
                  size: 16,
                  color: ShadTokens.destructive,
                ),
                SizedBox(width: ShadTokens.space2),
                Text(
                  '连接失败',
                  style: TextStyle(
                    fontSize: ShadTokens.fontBody,
                    fontWeight: FontWeight.w600,
                    color: ShadTokens.destructive,
                  ),
                ),
              ],
            ),
            const SizedBox(height: ShadTokens.space2),
            Text(
              '$_testError',
              style: const TextStyle(
                fontSize: ShadTokens.fontBody,
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(ShadTokens.space3),
      decoration: BoxDecoration(
        color: ShadTokens.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(ShadTokens.radiusDefault),
        border: Border.all(
          color: ShadTokens.success.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            RemixIcons.check_line,
            size: 16,
            color: ShadTokens.success,
          ),
          const SizedBox(width: ShadTokens.space2),
          Expanded(
            child: Text(
              '$_testSuccess',
              style: const TextStyle(
                fontSize: ShadTokens.fontBody,
              ),
            ),
          ),
        ],
      ),
    );
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
                    color: ShadTokens.primary,
                  ),
                  const SizedBox(width: ShadTokens.space2),
                  Text(
                    widget.editing == null ? '新建连接' : '编辑连接',
                    style: const TextStyle(
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
              const SizedBox(height: ShadTokens.space4),
              _LabeledField(
                label: '连接名称 *',
                child: TextFormField(
                  controller: _name,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    filled: false,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: ShadTokens.space3,
                      vertical: 12,
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? '请输入连接名称' : null,
                ),
              ),
              const SizedBox(height: ShadTokens.space4),
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
                            horizontal: ShadTokens.space3,
                            vertical: 12,
                          ),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? '请输入主机地址'
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: ShadTokens.space4),
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
                            horizontal: ShadTokens.space3,
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
              const SizedBox(height: ShadTokens.space4),
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
                            horizontal: ShadTokens.space3,
                            vertical: 12,
                          ),
                          hintText: 'root',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: ShadTokens.space4),
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
                            horizontal: ShadTokens.space3,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ShadTokens.space6),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: ShadTokens.border),
                  borderRadius:
                      BorderRadius.circular(ShadTokens.radiusDefault),
                ),
                clipBehavior: Clip.antiAlias,
                child: ExpansionTile(
                  initiallyExpanded: true,
                  maintainState: true,
                  tilePadding: const EdgeInsets.symmetric(
                    horizontal: ShadTokens.space3,
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(
                    ShadTokens.space3,
                    0,
                    ShadTokens.space3,
                    ShadTokens.space3,
                  ),
                  leading: const Icon(
                    RemixIcons.settings_3_line,
                    size: 16,
                    color: ShadTokens.mutedForeground,
                  ),
                  title: const Text(
                    '高级',
                    style: TextStyle(
                      fontSize: ShadTokens.fontBody,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  shape: const Border(),
                  collapsedShape: const Border(),
                  iconColor: ShadTokens.mutedForeground,
                  collapsedIconColor: ShadTokens.mutedForeground,
                  children: [
                    const SizedBox(height: ShadTokens.space2),
                    _AdvancedRow(
                      label: '超时（毫秒）',
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: SizedBox(
                          width: 180,
                          child: TextFormField(
                            controller: _timeout,
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              filled: false,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: ShadTokens.space3,
                                vertical: 8,
                              ),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: ShadTokens.space2),
                    _AdvancedRow(
                      label: 'HTTPS',
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Transform.scale(
                          scale: 0.75,
                          child: Switch.adaptive(
                            value: _enableSSL,
                            onChanged: (v) => setState(() => _enableSSL = v),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: ShadTokens.space2),
                    _AdvancedRow(
                      label: '自定义行数上限',
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (_useRowLimit)
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: SizedBox(
                                  width: 180,
                                  child: TextFormField(
                                    controller: _rowLimit,
                                    style: const TextStyle(fontSize: 13),
                                    decoration: InputDecoration(
                                      filled: false,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: ShadTokens.space3,
                                        vertical: 8,
                                      ),
                                    ),
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                              ),
                            ),
                          Checkbox(
                            value: _useRowLimit,
                            onChanged: (v) =>
                                setState(() => _useRowLimit = v ?? false),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: ShadTokens.space8),
              _buildMessageBar(),
              const SizedBox(height: ShadTokens.space6),
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
                      const SizedBox(width: ShadTokens.space2),
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
              const SizedBox(height: ShadTokens.space6),
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

/// 标签在前、控件在后的高级设置行
class _AdvancedRow extends StatelessWidget {
  final String label;
  final Widget child;

  const _AdvancedRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: ShadTokens.fontBody,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: ShadTokens.space3),
        Expanded(child: child),
      ],
    );
  }
}
