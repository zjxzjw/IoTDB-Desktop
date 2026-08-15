import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/providers.dart';
import '../../../core/theme/shadcn_tokens.dart';
import '../data/users_providers.dart';

/// 新建用户：`CREATE USER name 'password'`
Future<void> showCreateUserSheet(BuildContext context, WidgetRef ref) {
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
      child: const _CreateUserSheet(),
    ),
  );
}

class _CreateUserSheet extends ConsumerStatefulWidget {
  const _CreateUserSheet();

  @override
  ConsumerState<_CreateUserSheet> createState() => _CreateUserSheetState();
}

class _CreateUserSheetState extends ConsumerState<_CreateUserSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _name.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final sql = "CREATE USER ${_name.text.trim()} '${_password.text}'";
      await ref.read(iotdbClientProvider).nonQuery(sql);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('用户创建成功')));
      ref.invalidate(userListProvider);
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
              _SheetHeader(title: '新建用户', icon: RemixIcons.user_add_line),
              const SizedBox(height: ShadTokens.space3),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: '用户名 *', hintText: '如：alice'),
                validator: (v) => (v == null || v.trim().isEmpty) ? '请输入用户名' : null,
              ),
              const SizedBox(height: ShadTokens.space3),
              TextFormField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(labelText: '密码 *'),
                validator: (v) => (v == null || v.isEmpty) ? '请输入密码' : null,
              ),
              const SizedBox(height: ShadTokens.space3),
              TextFormField(
                controller: _confirm,
                obscureText: true,
                decoration: const InputDecoration(labelText: '确认密码 *'),
                validator: (v) => v != _password.text ? '两次输入的密码不一致' : null,
              ),
              const SizedBox(height: ShadTokens.space4),
              _SheetActions(
                submitting: _submitting,
                confirmText: '创建',
                onSubmit: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 修改密码：`ALTER USER name SET PASSWORD 'password'`
Future<void> showChangePasswordSheet(BuildContext context, WidgetRef ref, String username) {
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
      child: _ChangePasswordSheet(username: username),
    ),
  );
}

class _ChangePasswordSheet extends ConsumerStatefulWidget {
  final String username;

  const _ChangePasswordSheet({required this.username});

  @override
  ConsumerState<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends ConsumerState<_ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final sql = "ALTER USER ${widget.username} SET PASSWORD '${_password.text}'";
      await ref.read(iotdbClientProvider).nonQuery(sql);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('密码已修改')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('修改失败：$e')));
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
              const _SheetHeader(title: '修改密码', icon: RemixIcons.key_2_line),
              const SizedBox(height: ShadTokens.space2),
              Text(
                '用户：${widget.username}',
                style: const TextStyle(fontSize: 13, color: ShadTokens.mutedForeground),
              ),
              const SizedBox(height: ShadTokens.space3),
              TextFormField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(labelText: '新密码 *'),
                validator: (v) => (v == null || v.isEmpty) ? '请输入新密码' : null,
              ),
              const SizedBox(height: ShadTokens.space3),
              TextFormField(
                controller: _confirm,
                obscureText: true,
                decoration: const InputDecoration(labelText: '确认新密码 *'),
                validator: (v) => v != _password.text ? '两次输入的密码不一致' : null,
              ),
              const SizedBox(height: ShadTokens.space4),
              _SheetActions(
                submitting: _submitting,
                confirmText: '保存',
                onSubmit: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 新建角色：CREATE ROLE `<name>`
Future<void> showCreateRoleSheet(BuildContext context, WidgetRef ref) {
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
      child: const _CreateRoleSheet(),
    ),
  );
}

class _CreateRoleSheet extends ConsumerStatefulWidget {
  const _CreateRoleSheet();

  @override
  ConsumerState<_CreateRoleSheet> createState() => _CreateRoleSheetState();
}

class _CreateRoleSheetState extends ConsumerState<_CreateRoleSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await ref.read(iotdbClientProvider).nonQuery('CREATE ROLE ${_name.text.trim()}');
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('角色创建成功')));
      ref.invalidate(roleListProvider);
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
              const _SheetHeader(title: '新建角色', icon: RemixIcons.user_star_line),
              const SizedBox(height: ShadTokens.space3),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: '角色名 *', hintText: '如：readonly'),
                validator: (v) => (v == null || v.trim().isEmpty) ? '请输入角色名' : null,
              ),
              const SizedBox(height: ShadTokens.space4),
              _SheetActions(
                submitting: _submitting,
                confirmText: '创建',
                onSubmit: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 授权对话框：GRANT `<privs>` ON `<path>` TO USER|ROLE `<name>` [WITH GRANT OPTION]
Future<void> showGrantPrivilegeSheet(
  BuildContext context,
  WidgetRef ref,
  PrivilegeTarget target,
) {
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
      child: _GrantPrivilegeSheet(target: target),
    ),
  );
}

class _GrantPrivilegeSheet extends ConsumerStatefulWidget {
  final PrivilegeTarget target;

  const _GrantPrivilegeSheet({required this.target});

  @override
  ConsumerState<_GrantPrivilegeSheet> createState() => _GrantPrivilegeSheetState();
}

class _GrantPrivilegeSheetState extends ConsumerState<_GrantPrivilegeSheet> {
  final _formKey = GlobalKey<FormState>();
  final _scope = TextEditingController();
  final Set<String> _selected = {};
  bool _grantOption = false;
  bool _submitting = false;

  bool get _hasGlobal => _selected.any(Privileges.requiresRootScope);

  @override
  void dispose() {
    _scope.dispose();
    super.dispose();
  }

  void _toggle(String privilege, bool on) {
    setState(() {
      if (on) {
        _selected.add(privilege);
      } else {
        _selected.remove(privilege);
      }
      if (_hasGlobal) _scope.text = Privileges.rootScope;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selected.isEmpty) return;
    setState(() => _submitting = true);
    try {
      final sql = grantPrivilegesSql(
        widget.target.kind,
        widget.target.name,
        _selected.toList(),
        _scope.text.trim(),
        grantOption: _grantOption,
      );
      await ref.read(iotdbClientProvider).nonQuery(sql);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('授权成功')));
      ref.invalidate(privilegesProvider(PrivilegeTarget(widget.target.kind, widget.target.name)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('授权失败：$e')));
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
              _SheetHeader(
                title: '授权（${widget.target.kind.label} ${widget.target.name}）',
                icon: RemixIcons.shield_check_line,
              ),
              const SizedBox(height: ShadTokens.space3),
              const Text(
                '选择权限（可多选）',
                style: TextStyle(fontSize: ShadTokens.fontBody, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: ShadTokens.space2),
              Wrap(
                spacing: ShadTokens.space2,
                runSpacing: ShadTokens.space2,
                children: [
                  for (final p in Privileges.allGrantable)
                    FilterChip(
                      label: Text(p, style: const TextStyle(fontSize: 13)),
                      selected: _selected.contains(p),
                      onSelected: (on) => _toggle(p, on),
                      showCheckmark: false,
                    ),
                ],
              ),
              const SizedBox(height: ShadTokens.space3),
              TextFormField(
                controller: _scope,
                enabled: !_hasGlobal,
                decoration: InputDecoration(
                  labelText: '作用范围 *',
                  hintText: '如：db1 或 db1.table1',
                  helperText: _hasGlobal
                      ? '包含全局权限（SYSTEM/SECURITY/ALL）时，作用范围固定为 ${Privileges.rootScope}'
                      : '表模型下填写数据库名或 库.表，如：db1、db1.table1',
                  helperMaxLines: 2,
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? '请输入作用范围' : null,
              ),
              if (widget.target.kind == PrivilegeKind.user) ...[
                const SizedBox(height: ShadTokens.space2),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('WITH GRANT OPTION（允许该用户再授权给他人）', style: TextStyle(fontSize: 13)),
                  value: _grantOption,
                  onChanged: (v) => setState(() => _grantOption = v ?? false),
                ),
              ],
              const SizedBox(height: ShadTokens.space4),
              _SheetActions(
                submitting: _submitting,
                confirmText: '授权',
                onSubmit: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 表单标题行（图标 + 标题 + 关闭）
class _SheetHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SheetHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: ShadTokens.primary),
        const SizedBox(width: ShadTokens.space2),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: ShadTokens.fontTitle, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(RemixIcons.close_line, size: 18),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}

/// 底部操作按钮（取消 / 提交）
class _SheetActions extends StatelessWidget {
  final bool submitting;
  final String confirmText;
  final VoidCallback onSubmit;

  const _SheetActions({
    required this.submitting,
    required this.confirmText,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        const SizedBox(width: ShadTokens.space2),
        FilledButton(
          onPressed: submitting ? null : onSubmit,
          child: submitting
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(confirmText),
        ),
      ],
    );
  }
}
