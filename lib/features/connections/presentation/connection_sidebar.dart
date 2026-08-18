import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/models/connection.dart';
import '../../../core/providers.dart';
import '../../../core/theme/shadcn_tokens.dart';
import '../../settings/presentation/settings_dialog.dart';
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
  });

  @override
  ConsumerState<ConnectionSidebar> createState() => _ConnectionSidebarState();
}

class _ConnectionSidebarState extends ConsumerState<ConnectionSidebar> {
  static const int dbPageSize = 10;

  /// 当前展开（选中）的连接 id（手风琴：同一时间只展开一个）
  String? _expandedConnId;

  /// 各连接数据库列表已展示的数量（key = 连接 id）
  final Map<String, int> _dbVisibleCount = {};

  /// 各连接数据库列表是否已全部加载
  final Map<String, bool> _dbLoadedAll = {};

  void _handleOpen(Connection conn) {
    final willExpand = _expandedConnId != conn.id;
    setState(() {
      _expandedConnId = willExpand ? conn.id : null;
      if (willExpand) {
        _dbVisibleCount.putIfAbsent(conn.id, () => dbPageSize);
      }
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
                  foregroundColor: Colors.white,
                  backgroundColor: const Color(0xFF8e246c),
                  minimumSize: const Size.fromHeight(45),
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
            ?_buildPagingBar(),
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
            child: Text(
              'IoTDB Desktop',
              style: TextStyle(
                fontSize: ShadTokens.fontTitle,
                fontWeight: FontWeight.w600,
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
            expanded: _expandedConnId == conn.id,
            dbVisibleCount: _dbVisibleCount[conn.id] ?? dbPageSize,
            dbLoadedAll: _dbLoadedAll[conn.id] ?? false,
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
              setState(() {
                if (_expandedConnId == conn.id) _expandedConnId = null;
              });
              widget.onDisconnect(conn);
            },
            onSelectDatabase: (db) => widget.onSelectDatabase(conn, db),
          ),
        ],
      ],
    );
  }

  /// 底部「加载更多 / 全部加载」栏：作用于当前展开（选中）的连接
  Widget? _buildPagingBar() {
    final connId = _expandedConnId;
    if (connId == null) return null;
    Connection? target;
    for (final c in widget.connections) {
      if (c.id == connId) {
        target = c;
        break;
      }
    }
    if (target == null) return null;
    final conn = target;
    final result = ref.watch(connectionDatabaseListProvider(conn));
    return result.when(
      loading: () => null,
      error: (_, _) => null,
      data: (r) {
        final total = r.rows.length;
        if (total == 0) return null;
        final visible = _dbVisibleCount[conn.id] ?? dbPageSize;
        final loadedAll = _dbLoadedAll[conn.id] ?? false;
        final shown = loadedAll ? total : math.min(visible, total);
        return _buildPagingBarContent(conn, shown, total);
      },
    );
  }

  /// shadcn/ui 风格底部栏：信息 + 进度条 + 加载更多（outline）/ 全部加载（secondary）
  Widget _buildPagingBarContent(Connection conn, int shown, int total) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final canLoadMore = shown < total;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 8 * (1 - value)),
          child: child,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          ShadTokens.space3,
          ShadTokens.space2,
          ShadTokens.space2,
          ShadTokens.space3,
        ),
        decoration: BoxDecoration(
          color: ShadTokens.sidebar,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(
                  RemixIcons.database_2_line,
                  size: 14,
                  color: ShadTokens.mutedForeground,
                ),
                const SizedBox(width: ShadTokens.space2),
                Expanded(
                  child: Text(
                    '已显示 $shown / $total',
                    style: const TextStyle(
                      fontSize: ShadTokens.fontAux,
                      color: ShadTokens.mutedForeground,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: ShadTokens.space2),
                if (canLoadMore) ...[
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 30),
                      padding: const EdgeInsets.symmetric(
                        horizontal: ShadTokens.space2,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      side: BorderSide(
                        color: isLight
                            ? ShadTokens.border
                            : ShadTokens.borderDark,
                      ),
                      backgroundColor: Colors.transparent,
                      foregroundColor: isLight
                          ? ShadTokens.foreground
                          : ShadTokens.foregroundDark,
                      overlayColor:
                          isLight ? ShadTokens.hover : ShadTokens.hoverDark,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          ShadTokens.radiusDefault,
                        ),
                      ),
                      textStyle: const TextStyle(
                        fontSize: ShadTokens.fontAux,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        _dbVisibleCount[conn.id] =
                            (_dbVisibleCount[conn.id] ?? dbPageSize) +
                            dbPageSize;
                      });
                    },
                    child: const Text('加载更多'),
                  ),
                  const SizedBox(width: ShadTokens.space2),
                  TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 30),
                      padding: const EdgeInsets.symmetric(
                        horizontal: ShadTokens.space2,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      backgroundColor:
                          isLight ? ShadTokens.muted : ShadTokens.mutedDark,
                      foregroundColor: isLight
                          ? ShadTokens.foreground
                          : ShadTokens.foregroundDark,
                      overlayColor:
                          isLight ? ShadTokens.hover : ShadTokens.hoverDark,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          ShadTokens.radiusDefault,
                        ),
                      ),
                      textStyle: const TextStyle(
                        fontSize: ShadTokens.fontAux,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onPressed: () {
                      setState(() => _dbLoadedAll[conn.id] = true);
                    },
                    child: const Text('全部加载'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: ShadTokens.space2),
            ClipRRect(
              borderRadius: BorderRadius.circular(1.5),
              child: LinearProgressIndicator(
                value: shown / total,
                minHeight: 3,
                backgroundColor:
                    isLight ? ShadTokens.muted : ShadTokens.mutedDark,
                valueColor: AlwaysStoppedAnimation(
                  isLight ? ShadTokens.primary : ShadTokens.primaryDark,
                ),
              ),
            ),
          ],
        ),
      ),
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
  final int dbVisibleCount;
  final bool dbLoadedAll;
  final VoidCallback onActivate;
  final VoidCallback onRefresh;
  final VoidCallback onTest;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onDisconnect;
  final ValueChanged<String> onSelectDatabase;

  const _ConnectionNode({
    required this.conn,
    required this.expanded,
    required this.active,
    required this.status,
    required this.dbVisibleCount,
    required this.dbLoadedAll,
    required this.onActivate,
    required this.onRefresh,
    required this.onTest,
    required this.onEdit,
    required this.onDelete,
    required this.onDisconnect,
    required this.onSelectDatabase,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final connected = active || status == ConnectionStatus.success;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          borderRadius: BorderRadius.circular(ShadTokens.radiusDefault),
          color: expanded || active
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
                  if (connected)
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
                  if (connected)
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
                  if (connected)
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
                    duration: const Duration(milliseconds: 180),
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
        ClipRect(
          child: AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOutCubic,
            alignment: Alignment.topCenter,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(
                      ShadTokens.space3,
                      ShadTokens.space2,
                      0,
                      0,
                    ),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 150),
                      curve: Curves.easeOut,
                      builder: (context, value, child) => Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, 6 * (1 - value)),
                          child: child,
                        ),
                      ),
                      child: _DatabaseList(
                        conn: conn,
                        visibleCount: dbVisibleCount,
                        loadedAll: dbLoadedAll,
                        onSelectDatabase: onSelectDatabase,
                      ),
                    ),
                  )
                : const SizedBox(width: double.infinity),
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

class _DatabaseList extends ConsumerWidget {
  final Connection conn;
  final int visibleCount;
  final bool loadedAll;
  final ValueChanged<String> onSelectDatabase;

  const _DatabaseList({
    required this.conn,
    required this.visibleCount,
    required this.loadedAll,
    required this.onSelectDatabase,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(connectionDatabaseListProvider(conn));
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
      data: (r) {
        final total = r.rows.length;
        if (total == 0) {
          return const Padding(
            padding: EdgeInsets.all(ShadTokens.space2),
            child: Text(
              '无数据库',
              style: TextStyle(
                fontSize: ShadTokens.fontAux,
                color: ShadTokens.placeholder,
              ),
            ),
          );
        }
        final shown = loadedAll ? total : math.min(visibleCount, total);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final row in r.rows.take(shown))
              _DatabaseRow(
                db: row.first.toString(),
                onSelect: () => onSelectDatabase(row.first.toString()),
              ),
          ],
        );
      },
    );
  }
}

class _DatabaseRow extends ConsumerWidget {
  final String db;
  final VoidCallback onSelect;

  const _DatabaseRow({required this.db, required this.onSelect});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final selected = ref.watch(databaseSelectionProvider) == db;
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      selected: selected,
      selectedTileColor: (isLight
              ? ShadTokens.primary
              : ShadTokens.primaryDark)
          .withAlpha(26),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ShadTokens.radiusDefault),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: ShadTokens.space2),
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
      onTap: onSelect,
    );
  }
}
