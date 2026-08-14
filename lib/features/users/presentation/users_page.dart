import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/providers.dart';
import '../../../core/theme/shadcn_tokens.dart';
import '../../../shared/confirm_dialog.dart';
import '../../../shared/empty_state.dart';
import '../data/users_providers.dart';
import 'user_forms.dart';

/// 用户与权限页：用户/角色列表 + 权限详情编辑
class UsersPage extends ConsumerStatefulWidget {
  const UsersPage({super.key});

  @override
  ConsumerState<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends ConsumerState<UsersPage> {
  PrivilegeKind _kind = PrivilegeKind.user;
  String? _selected;

  @override
  void initState() {
    super.initState();
    ref.read(userListProvider);
  }

  void _switchKind(PrivilegeKind kind) {
    setState(() {
      _kind = kind;
      _selected = null;
    });
  }

  void _refresh() {
    ref.invalidate(_kind == PrivilegeKind.user ? userListProvider : roleListProvider);
    if (_selected != null) {
      ref.invalidate(privilegesProvider(PrivilegeTarget(_kind, _selected!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(),
        const Divider(height: 1),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 280, child: _buildListPane()),
              const VerticalDivider(width: 1),
              Expanded(child: _buildDetailPane()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ShadTokens.space4, vertical: ShadTokens.space3),
      child: Row(
        children: [
          const Icon(RemixIcons.shield_user_line, size: 16, color: ShadTokens.primary),
          const SizedBox(width: ShadTokens.space2),
          const Text(
            '用户与权限',
            style: TextStyle(fontSize: ShadTokens.fontTitle, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          if (_kind == PrivilegeKind.user && _selected != null)
            FilledButton.icon(
              onPressed: () => showGrantPrivilegeSheet(context, ref, PrivilegeTarget(_kind, _selected!)),
              icon: const Icon(RemixIcons.shield_keyhole_line, size: 16),
              label: const Text('授权'),
            ),
          const SizedBox(width: ShadTokens.space2),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: '刷新',
            onPressed: _refresh,
            icon: const Icon(RemixIcons.refresh_line, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildListPane() {
    final isUser = _kind == PrivilegeKind.user;
    final list = ref.watch(isUser ? userListProvider : roleListProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(ShadTokens.space4, ShadTokens.space3, ShadTokens.space4, 0),
          child: Row(
            children: [
              SegmentedButton<PrivilegeKind>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: PrivilegeKind.user, label: Text('用户')),
                  ButtonSegment(value: PrivilegeKind.role, label: Text('角色')),
                ],
                selected: {_kind},
                onSelectionChanged: (s) => _switchKind(s.first),
              ),
              const Spacer(),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: isUser ? '新建用户' : '新建角色',
                onPressed: () => isUser
                    ? showCreateUserSheet(context, ref)
                    : showCreateRoleSheet(context, ref),
                icon: const Icon(RemixIcons.add_line, size: 18, color: ShadTokens.primary),
              ),
            ],
          ),
        ),
        const SizedBox(height: ShadTokens.space2),
        const Divider(height: 1),
        Expanded(
          child: list.when(
            loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(ShadTokens.space4),
                child: Text('加载失败：$e', style: const TextStyle(color: ShadTokens.destructive)),
              ),
            ),
            data: (r) {
              final names = isUser
                  ? [for (final row in r.rows) row.length > 1 ? '${row[1]}' : '${row.first}']
                  : [for (final row in r.rows) '${row.first}'];
              if (names.isEmpty) {
                return EmptyState(
                  icon: RemixIcons.user_line,
                  title: isUser ? '暂无用户' : '暂无角色',
                  description: '点击右上角 + 新建',
                );
              }
              return ListView.separated(
                itemCount: names.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final name = names[i];
                  final selected = name == _selected;
                  return InkWell(
                    onTap: () => setState(() => _selected = name),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: ShadTokens.space4, vertical: ShadTokens.space2),
                      color: selected ? ShadTokens.muted : null,
                      child: Row(
                        children: [
                          Icon(
                            isUser ? RemixIcons.user_line : RemixIcons.user_star_line,
                            size: 15,
                            color: selected ? ShadTokens.primary : ShadTokens.mutedForeground,
                          ),
                          const SizedBox(width: ShadTokens.space2),
                          Expanded(
                            child: Text(
                              name,
                              style: TextStyle(
                                fontSize: ShadTokens.fontBody,
                                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                                color: selected ? ShadTokens.primary : ShadTokens.foreground,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (name == 'root')
                            const Text(
                              '管理员',
                              style: TextStyle(fontSize: 11, color: ShadTokens.placeholder),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDetailPane() {
    final selected = _selected;
    if (selected == null) {
      return EmptyState(
        icon: RemixIcons.shield_user_line,
        title: '选择${_kind.label}查看权限',
        description: '左侧选择${_kind.label}，右侧展示其权限并支持授权/撤销',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: ShadTokens.space4, vertical: ShadTokens.space3),
          child: Row(
            children: [
              Icon(
                _kind == PrivilegeKind.user ? RemixIcons.user_line : RemixIcons.user_star_line,
                size: 16,
                color: ShadTokens.primary,
              ),
              const SizedBox(width: ShadTokens.space2),
              Expanded(
                child: Text(
                  selected,
                  style: const TextStyle(fontSize: ShadTokens.fontTitle, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_kind == PrivilegeKind.user) ...[
                if (selected != 'root') ...[
                  OutlinedButton.icon(
                    onPressed: () => showChangePasswordSheet(context, ref, selected),
                    icon: const Icon(RemixIcons.key_2_line, size: 16),
                    label: const Text('修改密码'),
                  ),
                  const SizedBox(width: ShadTokens.space2),
                  FilledButton.icon(
                    onPressed: () => showGrantPrivilegeSheet(context, ref, PrivilegeTarget(_kind, selected)),
                    icon: const Icon(RemixIcons.shield_keyhole_line, size: 16),
                    label: const Text('授权'),
                  ),
                ],
              ] else ...[
                FilledButton.icon(
                  onPressed: () => showGrantPrivilegeSheet(context, ref, PrivilegeTarget(_kind, selected)),
                  icon: const Icon(RemixIcons.shield_keyhole_line, size: 16),
                  label: const Text('授权'),
                ),
              ],
              const SizedBox(width: ShadTokens.space2),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: _kind == PrivilegeKind.user ? '删除用户' : '删除角色',
                onPressed: selected == 'root' ? null : () => _deleteSelected(),
                icon: Icon(
                  RemixIcons.delete_bin_line,
                  size: 18,
                  color: selected == 'root' ? ShadTokens.textDisabled : ShadTokens.destructive,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _buildPrivilegeList(),
        ),
        if (selected == 'root')
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(ShadTokens.space3),
            color: ShadTokens.muted,
            child: const Text(
              'root 为内置管理员，拥有全部权限且不可修改',
              style: TextStyle(fontSize: ShadTokens.fontAux, color: ShadTokens.mutedForeground),
            ),
          ),
      ],
    );
  }

  Future<void> _deleteSelected() async {
    final selected = _selected;
    if (selected == null) return;
    final ok = await showConfirmDialog(
      context,
      title: _kind == PrivilegeKind.user ? '删除用户' : '删除角色',
      message: '确定删除${_kind.label}「$selected」？',
      confirmText: '删除',
      confirmColor: ShadTokens.destructive,
    );
    if (!ok) return;
    try {
      await ref
          .read(iotdbClientProvider)
          .nonQuery('DROP ${_kind == PrivilegeKind.user ? 'USER' : 'ROLE'} $selected');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${_kind.label}已删除')));
      ref.invalidate(_kind == PrivilegeKind.user ? userListProvider : roleListProvider);
      setState(() => _selected = null);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('删除失败：$e')));
    }
  }

  Widget _buildPrivilegeList() {
    final selected = _selected;
    if (selected == null) return const SizedBox.shrink();
    final target = PrivilegeTarget(_kind, selected);
    final result = ref.watch(privilegesProvider(target));
    return result.when(
      loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(ShadTokens.space4),
          child: Text('加载失败：$e', style: const TextStyle(color: ShadTokens.destructive)),
        ),
      ),
      data: (r) {
        final entries = parsePrivileges(r);
        if (entries.isEmpty) {
          return const EmptyState(
            icon: RemixIcons.shield_keyhole_line,
            title: '暂无权限',
            description: '点击右上角「授权」为该账号添加权限',
          );
        }
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(ShadTokens.space4),
            child: DataTable(
              headingRowColor: WidgetStatePropertyAll(ShadTokens.muted),
              horizontalMargin: ShadTokens.space4,
              columnSpacing: ShadTokens.space4,
              columns: const [
                DataColumn(label: Text('权限')),
                DataColumn(label: Text('作用路径')),
                DataColumn(label: Text('来源')),
                DataColumn(label: Text('可再授权')),
                DataColumn(label: Text('')),
              ],
              rows: [
                for (final e in entries)
                  DataRow(
                    cells: [
                      DataCell(
                        Text(
                          e.privilege,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      DataCell(
                        Text(
                          e.isGlobal ? Privileges.rootScope : e.scope,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      DataCell(
                        Text(
                          e.fromRole ? '角色 ${e.role}' : '直接授权',
                          style: TextStyle(
                            fontSize: 13,
                            color: e.fromRole ? ShadTokens.warning : ShadTokens.mutedForeground,
                          ),
                        ),
                      ),
                      DataCell(
                        e.grantOption
                            ? const Icon(RemixIcons.check_line, size: 16, color: ShadTokens.success)
                            : const Icon(RemixIcons.close_line, size: 16, color: ShadTokens.textDisabled),
                      ),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!e.fromRole && selected != 'root')
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                tooltip: '撤销权限',
                                icon: const Icon(RemixIcons.recycle_line, size: 16, color: ShadTokens.destructive),
                                onPressed: () => _revoke(e),
                              ),
                            if (e.fromRole)
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                tooltip: '来自角色 ${e.role}，请到角色页修改',
                                icon: Icon(
                                  RemixIcons.arrow_go_back_line,
                                  size: 16,
                                  color: ShadTokens.textDisabled,
                                ),
                                onPressed: () {},
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _revoke(PrivilegeEntry entry) async {
    final selected = _selected;
    if (selected == null || entry.fromRole) return;
    final ok = await showConfirmDialog(
      context,
      title: '撤销权限',
      message: '确定撤销 ${_kind.label}「$selected」的权限 ${entry.privilege}（${entry.isGlobal ? Privileges.rootScope : entry.scope}）？',
      confirmText: '撤销',
      confirmColor: ShadTokens.destructive,
    );
    if (!ok) return;
    try {
      await ref
          .read(iotdbClientProvider)
          .nonQuery(revokePrivilegeSql(_kind, selected, entry.privilege, entry.scope));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('权限已撤销')));
      ref.invalidate(privilegesProvider(PrivilegeTarget(_kind, selected)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('撤销失败：$e')));
    }
  }
}
