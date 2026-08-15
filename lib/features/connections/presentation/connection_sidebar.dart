import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/models/connection.dart';
import '../../../core/providers.dart';
import '../../../core/theme/shadcn_tokens.dart';
import '../../settings/presentation/settings_dialog.dart';
import '../../database/data/database_providers.dart';
import 'connection_form_sheet.dart';

/// 侧边栏：连接树（可展开显示数据库 → 表）+ 新建入口
class ConnectionSidebar extends ConsumerStatefulWidget {
  final List<Connection> connections;
  final bool loading;
  final ValueChanged<Connection> onOpen;
  final ValueChanged<Connection> onTest;
  final ValueChanged<Connection> onEdit;
  final ValueChanged<Connection> onDelete;
  final ValueChanged<Connection> onDisconnect;
  final void Function(Connection conn, String db) onSelectDatabase;
  final void Function(Connection conn, String db, String table) onSelectTable;

  const ConnectionSidebar({
    super.key,
    required this.connections,
    required this.loading,
    required this.onOpen,
    required this.onTest,
    required this.onEdit,
    required this.onDelete,
    required this.onDisconnect,
    required this.onSelectDatabase,
    required this.onSelectTable,
  });

  @override
  ConsumerState<ConnectionSidebar> createState() => _ConnectionSidebarState();
}

class _ConnectionSidebarState extends ConsumerState<ConnectionSidebar> {
  /// 已展开的连接 id（点击连接后保持展开）
  final Set<String> _expanded = {};

  void _handleOpen(Connection conn) {
    final willExpand = !_expanded.contains(conn.id);
    setState(() {
      willExpand ? _expanded.add(conn.id) : _expanded.remove(conn.id);
    });
    if (willExpand &&
        ref.read(connectionStatusProvider)[conn.id] !=
            ConnectionStatus.success) {
      widget.onOpen(conn);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ShadTokens.sidebar,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context, ref),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                ShadTokens.space2,
                ShadTokens.space3,
                ShadTokens.space2,
                ShadTokens.space3,
              ),
              child: FilledButton.icon(
                onPressed: () => showConnectionFormDialog(context, ref),
                icon: const Icon(RemixIcons.add_line, size: 16),
                label: const Text('新建连接'),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      ShadTokens.radiusDefault,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: widget.loading
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : widget.connections.isEmpty
                  ? _buildEmpty(context, ref)
                  : _buildList(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ShadTokens.space4,
        ShadTokens.space3,
        ShadTokens.space3,
        ShadTokens.space3,
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text.rich(
              TextSpan(
                text: 'IoTDB Desktop',
                style: TextStyle(
                  fontSize: ShadTokens.fontTitle,
                  fontWeight: FontWeight.w600,
                ),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: () => showSettingsDialog(context, ref),
            icon: const Icon(RemixIcons.settings_3_line, size: 18),
            tooltip: '设置',
            color: ShadTokens.mutedForeground,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeConnectionProvider);
    final statuses = ref.watch(connectionStatusProvider);
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: ShadTokens.space2),
      children: [
        for (final conn in widget.connections) ...[
          const SizedBox(height: ShadTokens.space2),
          _ConnectionNode(
            conn: conn,
            expanded: _expanded.contains(conn.id),
            active: conn.id == active?.id,
            status: statuses[conn.id] ?? ConnectionStatus.unknown,
            onActivate: () => _handleOpen(conn),
            onRefresh: () {
              ref.invalidate(connectionDatabaseListProvider(conn));
            },
            onTest: () => widget.onTest(conn),
            onEdit: () => widget.onEdit(conn),
            onDelete: () => widget.onDelete(conn),
            onDisconnect: () {
              setState(() => _expanded.remove(conn.id));
              widget.onDisconnect(conn);
            },
            onSelectDatabase: (db) => widget.onSelectDatabase(conn, db),
            onSelectTable: (db, table) => widget.onSelectTable(conn, db, table),
          ),
        ],
      ],
    );
  }

  Widget _buildEmpty(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            RemixIcons.plug_line,
            size: 32,
            color: ShadTokens.placeholder,
          ),
          const SizedBox(height: ShadTokens.space2),
          const Text(
            '暂无连接',
            style: TextStyle(fontSize: 13, color: ShadTokens.placeholder),
          ),
          const SizedBox(height: ShadTokens.space3),
          TextButton.icon(
            onPressed: () => showConnectionFormDialog(context, ref),
            icon: const Icon(RemixIcons.add_line, size: 16),
            label: const Text('新建连接'),
          ),
        ],
      ),
    );
  }
}

class _ConnectionNode extends StatelessWidget {
  final Connection conn;
  final bool expanded;
  final bool active;
  final ConnectionStatus status;
  final VoidCallback onActivate;
  final VoidCallback onRefresh;
  final VoidCallback onTest;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onDisconnect;
  final ValueChanged<String> onSelectDatabase;
  final void Function(String db, String table) onSelectTable;

  const _ConnectionNode({
    required this.conn,
    required this.expanded,
    required this.active,
    required this.status,
    required this.onActivate,
    required this.onRefresh,
    required this.onTest,
    required this.onEdit,
    required this.onDelete,
    required this.onDisconnect,
    required this.onSelectDatabase,
    required this.onSelectTable,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          borderRadius: BorderRadius.circular(ShadTokens.radiusDefault),
          color: active
              ? (isLight
                    ? ShadTokens.sidebarActive
                    : ShadTokens.sidebarActiveDark)
              : Colors.transparent,
          child: InkWell(
            onTap: onActivate,
            borderRadius: BorderRadius.circular(ShadTokens.radiusDefault),
            hoverColor: isLight ? Colors.white : ShadTokens.sidebarHoverDark,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: ShadTokens.space2,
                vertical: ShadTokens.space2,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 8,
                    height: 8,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: _dotColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: ShadTokens.space2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          conn.name,
                          style: const TextStyle(
                            fontSize: ShadTokens.fontBody,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${conn.host}:${conn.port}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: ShadTokens.placeholder,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: '刷新',
                    onPressed: onRefresh,
                    icon: const Icon(
                      RemixIcons.refresh_line,
                      size: 16,
                      color: ShadTokens.mutedForeground,
                    ),
                  ),
                  if (active || status == ConnectionStatus.success)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: '断开连接',
                      onPressed: onDisconnect,
                      icon: const Icon(
                        RemixIcons.link_unlink,
                        size: 16,
                        color: ShadTokens.mutedForeground,
                      ),
                    ),
                  PopupMenuButton<_ConnAction>(
                    tooltip: '操作',
                    icon: const Icon(
                      RemixIcons.more_line,
                      size: 16,
                      color: ShadTokens.mutedForeground,
                    ),
                    onSelected: (action) => switch (action) {
                      _ConnAction.test => onTest(),
                      _ConnAction.edit => onEdit(),
                      _ConnAction.delete => onDelete(),
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: _ConnAction.test,
                        child: Text('测试连接'),
                      ),
                      PopupMenuItem(
                        value: _ConnAction.edit,
                        child: Text('编辑连接'),
                      ),
                      PopupMenuItem(
                        value: _ConnAction.delete,
                        child: Text('删除连接'),
                      ),
                    ],
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.25 : 0.0,
                    duration: const Duration(milliseconds: 150),
                    child: Icon(
                      RemixIcons.arrow_right_s_line,
                      size: 16,
                      color: expanded
                          ? ShadTokens.mutedForeground
                          : ShadTokens.placeholder,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              ShadTokens.space3,
              ShadTokens.space2,
              0,
              0,
            ),
            child: _DatabaseList(
              conn: conn,
              onSelectDatabase: onSelectDatabase,
              onSelectTable: onSelectTable,
            ),
          ),
      ],
    );
  }

  Color get _dotColor {
    if (status == ConnectionStatus.failure) return ShadTokens.destructive;
    if (active || status == ConnectionStatus.success) return ShadTokens.success;
    return ShadTokens.placeholder;
  }
}

enum _ConnAction { test, edit, delete }

class _DatabaseList extends ConsumerStatefulWidget {
  final Connection conn;
  final ValueChanged<String> onSelectDatabase;
  final void Function(String db, String table) onSelectTable;

  const _DatabaseList({
    required this.conn,
    required this.onSelectDatabase,
    required this.onSelectTable,
  });

  @override
  ConsumerState<_DatabaseList> createState() => _DatabaseListState();
}

class _DatabaseListState extends ConsumerState<_DatabaseList> {
  final Set<String> _expanded = {};

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(connectionDatabaseListProvider(widget.conn));
    return result.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(ShadTokens.space3),
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(ShadTokens.space2),
        child: Text(
          '加载失败：$e',
          style: const TextStyle(
            fontSize: ShadTokens.fontAux,
            color: ShadTokens.destructive,
          ),
        ),
      ),
      data: (r) => r.rows.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(ShadTokens.space2),
              child: Text(
                '无数据库',
                style: TextStyle(
                  fontSize: ShadTokens.fontAux,
                  color: ShadTokens.placeholder,
                ),
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final row in r.rows)
                  _DatabaseRow(
                    conn: widget.conn,
                    db: row.first.toString(),
                    expanded: _expanded.contains(row.first.toString()),
                    onToggle: () => setState(() {
                      final db = row.first.toString();
                      _expanded.contains(db)
                          ? _expanded.remove(db)
                          : _expanded.add(db);
                    }),
                    onSelect: () => widget.onSelectDatabase(row.first.toString()),
                    onSelectTable: widget.onSelectTable,
                  ),
              ],
            ),
    );
  }
}

class _DatabaseRow extends ConsumerWidget {
  final Connection conn;
  final String db;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onSelect;
  final void Function(String db, String table) onSelectTable;

  const _DatabaseRow({
    required this.conn,
    required this.db,
    required this.expanded,
    required this.onToggle,
    required this.onSelect,
    required this.onSelectTable,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final selected = ref.watch(databaseSelectionProvider) == db;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: ShadTokens.space2,
          ),
          leading: Icon(
            RemixIcons.database_2_line,
            size: 15,
            color: selected
                ? (isLight ? ShadTokens.primary : ShadTokens.primaryDark)
                : ShadTokens.mutedForeground,
          ),
          title: Text(
            db,
            style: TextStyle(
              fontSize: ShadTokens.fontBody,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected
                  ? (isLight ? ShadTokens.foreground : ShadTokens.foregroundDark)
                  : (isLight
                        ? ShadTokens.mutedForeground
                        : ShadTokens.mutedForegroundDark),
            ),
            overflow: TextOverflow.ellipsis,
          ),
          trailing: AnimatedRotation(
            turns: expanded ? 0.25 : 0.0,
            duration: const Duration(milliseconds: 150),
            child: const Icon(
              RemixIcons.arrow_right_s_line,
              size: 15,
              color: ShadTokens.placeholder,
            ),
          ),
          onTap: () {
            onToggle();
            onSelect();
          },
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.only(left: ShadTokens.space3),
            child: _TableList(conn: conn, db: db, onSelectTable: onSelectTable),
          ),
      ],
    );
  }
}

class _TableList extends ConsumerWidget {
  final Connection conn;
  final String db;
  final void Function(String db, String table) onSelectTable;

  const _TableList({
    required this.conn,
    required this.db,
    required this.onSelectTable,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(connectionTableListProvider(TableScope(conn, db)));
    return result.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(ShadTokens.space3),
        child: Center(
          child: SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(ShadTokens.space2),
        child: Text(
          '加载失败：$e',
          style: const TextStyle(
            fontSize: ShadTokens.fontAux,
            color: ShadTokens.destructive,
          ),
        ),
      ),
      data: (r) => r.rows.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(ShadTokens.space2),
              child: Text(
                '无表',
                style: TextStyle(
                  fontSize: ShadTokens.fontAux,
                  color: ShadTokens.placeholder,
                ),
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final row in r.rows)
                  _TableTile(
                    db: db,
                    table: row.first.toString(),
                    onSelect: () => onSelectTable(db, row.first.toString()),
                  ),
              ],
            ),
    );
  }
}

class _TableTile extends ConsumerWidget {
  final String db;
  final String table;
  final VoidCallback onSelect;

  const _TableTile({
    required this.db,
    required this.table,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected =
        ref.watch(tableSelectionProvider) == table &&
        ref.watch(databaseSelectionProvider) == db;
    final isLight = Theme.of(context).brightness == Brightness.light;
    return InkWell(
      onTap: onSelect,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: ShadTokens.space2,
          vertical: 5,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ShadTokens.radiusDefault),
          color: selected
              ? (isLight ? ShadTokens.sidebarActive : ShadTokens.sidebarActiveDark)
              : null,
        ),
        child: Row(
          children: [
            Icon(
              RemixIcons.table_line,
              size: 14,
              color: selected
                  ? (isLight ? ShadTokens.primary : ShadTokens.primaryDark)
                  : ShadTokens.mutedForeground,
            ),
            const SizedBox(width: ShadTokens.space2),
            Expanded(
              child: Text(
                table,
                style: TextStyle(
                  fontSize: ShadTokens.fontBody,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected
                      ? (isLight
                            ? ShadTokens.foreground
                            : ShadTokens.foregroundDark)
                      : (isLight
                            ? ShadTokens.mutedForeground
                            : ShadTokens.mutedForegroundDark),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
