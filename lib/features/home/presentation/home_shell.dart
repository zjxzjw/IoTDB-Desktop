import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/models/connection.dart';
import '../../../core/network/iotdb_client.dart';
import '../../../core/providers.dart';
import '../../../core/storage/app_settings_store.dart';
import '../../../core/theme/shadcn_tokens.dart';
import '../../../shared/confirm_dialog.dart';
import '../../connections/presentation/connection_form_sheet.dart';
import '../../connections/presentation/connection_sidebar.dart';
import '../../dashboard/presentation/dashboard_page.dart';
import '../../data/presentation/data_browse_page.dart';
import '../../database/presentation/create_database_form.dart';
import '../../database/presentation/table_page.dart';
import '../../sql/presentation/sql_workbench_page.dart';
import '../../users/presentation/users_page.dart';

/// 工作区标题栏「更多」菜单操作
enum _WorkspaceConnAction { test, edit, delete }

/// 应用外壳：左侧连接侧边栏（可拖拽调整宽度）+ 右侧内容区
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  double _sidebarWidth = AppSettingsStore.defaultSidebarWidth;
  bool _dragActive = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual(sidebarWidthProvider, (prev, next) {
      if (!_dragActive && next.hasValue && mounted) {
        setState(() => _sidebarWidth = next.value!);
      }
    });
  }

  void _onDragStart() {
    _dragActive = true;
  }

  void _onDrag(double dx) {
    setState(() {
      _sidebarWidth = (_sidebarWidth + dx).clamp(
        AppSettingsStore.minSidebarWidth,
        AppSettingsStore.maxSidebarWidth,
      );
    });
  }

  void _onDragEnd() {
    _dragActive = false;
    ref.read(sidebarWidthProvider.notifier).setWidth(_sidebarWidth);
  }

  Future<void> _openWorkspace(WidgetRef ref, Connection conn) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      ref.read(connectionStatusProvider.notifier).markSuccess(conn.id);
      ref.read(databaseSelectionProvider.notifier).clear();
      ref.read(tableSelectionProvider.notifier).clear();
      ref.read(activeConnectionProvider.notifier).set(conn);
      ref.read(workspaceViewProvider.notifier).showDashboard();
    } catch (e) {
      ref.read(connectionStatusProvider.notifier).markFailure(conn.id);
      messenger.showSnackBar(SnackBar(content: Text('连接失败：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(sidebarWidthProvider);

    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: _sidebarWidth,
            child: ref
                .watch(connectionStoreProvider)
                .when(
                  loading: () => const ConnectionSidebar(
                    connections: [],
                    loading: true,
                    onOpen: _noop,
                    onTest: _noop,
                    onEdit: _noop,
                    onDelete: _noop,
                    onDisconnect: _noop,
                    onSelectDatabase: _noopSelectDb,
                    onSelectTable: _noopSelectTable,
                  ),
                  error: (e, _) => const ConnectionSidebar(
                    connections: [],
                    loading: false,
                    onOpen: _noop,
                    onTest: _noop,
                    onEdit: _noop,
                    onDelete: _noop,
                    onDisconnect: _noop,
                    onSelectDatabase: _noopSelectDb,
                    onSelectTable: _noopSelectTable,
                  ),
                  data: (list) => ConnectionSidebar(
                    connections: list,
                    loading: false,
                    onOpen: (c) => _openWorkspace(ref, c),
                    onTest: (c) => _testConnection(context, ref, c),
                    onEdit: (c) =>
                        showConnectionFormDialog(context, ref, editing: c),
                    onDelete: (c) => _deleteConnection(context, ref, c),
                    onDisconnect: (c) => _disconnectConnection(ref, c),
                    onSelectDatabase: (c, db) => _selectDatabase(ref, c, db),
                    onSelectTable: (c, db, table) =>
                        _selectTable(ref, c, db, table),
                  ),
                ),
          ),
          _SidebarResizeHandle(
            onDragStart: _onDragStart,
            onDrag: _onDrag,
            onDragEnd: _onDragEnd,
          ),
          Expanded(
            child: ref.watch(activeConnectionProvider) == null
                ? const _WelcomePane()
                : const WorkspaceScreen(),
          ),
        ],
      ),
    );
  }

  static void _noop(Connection c) {}

  static void _noopSelectDb(Connection c, String db) {}

  static void _noopSelectTable(Connection c, String db, String table) {}

  /// 点击侧栏数据库：激活对应连接，切到「表管理」并选中该数据库
  Future<void> _selectDatabase(
    WidgetRef ref,
    Connection conn,
    String db,
  ) async {
    final active = ref.read(activeConnectionProvider);
    if (active?.id != conn.id) {
      await _openWorkspace(ref, conn);
      if (ref.read(activeConnectionProvider)?.id != conn.id) return;
    }
    ref.read(databaseSelectionProvider.notifier).select(db);
    ref.read(tableSelectionProvider.notifier).clear();
    ref.read(workspaceViewProvider.notifier).showTabs();
    ref.read(workspaceTabProvider.notifier).select(0);
  }

  /// 点击侧栏表：激活对应连接，切到「表管理」并选中该表
  Future<void> _selectTable(
    WidgetRef ref,
    Connection conn,
    String db,
    String table,
  ) async {
    final active = ref.read(activeConnectionProvider);
    if (active?.id != conn.id) {
      await _openWorkspace(ref, conn);
      if (ref.read(activeConnectionProvider)?.id != conn.id) return;
    }
    ref.read(databaseSelectionProvider.notifier).select(db);
    ref.read(tableSelectionProvider.notifier).select(table);
    ref.read(workspaceViewProvider.notifier).showTabs();
    ref.read(workspaceTabProvider.notifier).select(0);
  }

  Future<void> _testConnection(
    BuildContext context,
    WidgetRef ref,
    Connection conn,
  ) => _testConnectionAction(context, ref, conn);

  Future<void> _deleteConnection(
    BuildContext context,
    WidgetRef ref,
    Connection conn,
  ) => _deleteConnectionAction(context, ref, conn);

  void _disconnectConnection(WidgetRef ref, Connection conn) =>
      _disconnectConnectionAction(context, ref, conn);
}

/// 测试连接：ping + 版本查询，更新状态点
Future<void> _testConnectionAction(
  BuildContext context,
  WidgetRef ref,
  Connection conn,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final client = IotdbClient(conn);
    final ms = await client.ping();
    ref.read(connectionStatusProvider.notifier).markSuccess(conn.id);
    String version = '';
    try {
      final r = await client.query('SHOW VERSION');
      version = r.rows.isNotEmpty ? '${r.rows.first.first}' : '';
    } catch (_) {}
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          '连接成功（${ms}ms）${version.isEmpty ? '' : '，服务端版本 $version'}',
        ),
      ),
    );
  } catch (e) {
    ref.read(connectionStatusProvider.notifier).markFailure(conn.id);
    messenger.showSnackBar(SnackBar(content: Text('连接失败：$e')));
  }
}

/// 删除连接；若删除的是当前活动连接则同时断开并回到欢迎页
Future<void> _deleteConnectionAction(
  BuildContext context,
  WidgetRef ref,
  Connection conn,
) async {
  final confirmed = await showConfirmDialog(
    context,
    title: '删除连接',
    message: '确定删除连接「${conn.name}」？该操作不可恢复。',
    confirmText: '删除',
    confirmColor: ShadTokens.destructive,
  );
  if (!confirmed) return;
  await ref.read(connectionStoreProvider.notifier).remove(conn.id);
  if (ref.read(activeConnectionProvider)?.id == conn.id) {
    ref.read(activeConnectionProvider.notifier).clear();
    ref.read(databaseSelectionProvider.notifier).clear();
    ref.read(tableSelectionProvider.notifier).clear();
  }
  ref.read(connectionStatusProvider.notifier).disconnect(conn.id);
  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已删除连接')));
  }
}

/// 断开连接：清除状态与活动连接（回到欢迎页）
void _disconnectConnectionAction(
  BuildContext context,
  WidgetRef ref,
  Connection conn,
) {
  final active = ref.read(activeConnectionProvider);
  if (active?.id == conn.id) {
    ref.read(activeConnectionProvider.notifier).clear();
    ref.read(databaseSelectionProvider.notifier).clear();
    ref.read(tableSelectionProvider.notifier).clear();
  }
  ref.read(connectionStatusProvider.notifier).disconnect(conn.id);
}

class _WelcomePane extends ConsumerWidget {
  const _WelcomePane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list =
        ref.watch(connectionStoreProvider).value ?? const <Connection>[];
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            list.isEmpty ? '欢迎使用 Desktop' : '选择一个连接开始管理',
            style: const TextStyle(
              fontSize: ShadTokens.fontPage,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: ShadTokens.space2),
          const Text(
            '点击左侧连接展开数据库列表并进入工作区',
            style: TextStyle(fontSize: 13, color: ShadTokens.mutedForeground),
          ),
        ],
      ),
    );
  }
}

/// 侧边栏右缘拖拽滑块：无缝隙分隔左右区域，鼠标移入浮现滑块并高亮，拖拽改变宽度
class _SidebarResizeHandle extends StatefulWidget {
  final VoidCallback onDragStart;
  final ValueChanged<double> onDrag;
  final VoidCallback onDragEnd;

  const _SidebarResizeHandle({
    required this.onDragStart,
    required this.onDrag,
    required this.onDragEnd,
  });

  @override
  State<_SidebarResizeHandle> createState() => _SidebarResizeHandleState();
}

class _SidebarResizeHandleState extends State<_SidebarResizeHandle> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) => widget.onDragStart(),
        onHorizontalDragUpdate: (d) => widget.onDrag(d.delta.dx),
        onHorizontalDragEnd: (_) => widget.onDragEnd(),
        onHorizontalDragCancel: widget.onDragEnd,
        child: SizedBox(
          width: 6,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                top: 0,
                bottom: 0,
                width: 1,
                child: ColoredBox(
                  color: _hovered
                      ? Theme.of(context).colorScheme.primary
                      : ShadTokens.border,
                ),
              ),
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: _hovered
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 工作区上下分区横向拖拽手柄：鼠标悬停显示调整光标，拖拽改变 SQL 区高度
class _WorkspaceResizeHandle extends StatelessWidget {
  final ValueChanged<double> onDrag;

  const _WorkspaceResizeHandle({required this.onDrag});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeUpDown,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: (d) => onDrag(d.delta.dy),
        onVerticalDragEnd: (_) {},
        child: SizedBox(
          height: 6,
          child: Center(
            child: Container(
              width: double.infinity,
              height: 1,
              color: ShadTokens.border,
            ),
          ),
        ),
      ),
    );
  }
}

/// 工作区：仪表盘独立页面（默认）或 Tab 容器（SQL 工作台 / 数据库管理 / 用户与权限 / 数据浏览）
class WorkspaceScreen extends ConsumerStatefulWidget {
  const WorkspaceScreen({super.key});

  @override
  ConsumerState<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends ConsumerState<WorkspaceScreen> {
  static const double _tabBarHeight = 48;
  static const double _resizeHandleHeight = 6;
  static const double _minSqlHeight = 120;
  static const double _minContentHeight = 120;

  /// 默认收起：下方仅显示 Tab 切换条，不显示内容区
  bool _tabsExpanded = false;

  /// SQL 区像素高度（首次展开按总量 × 0.45 初始化，之后记住用户拖拽结果）
  double _sqlHeight = 0;

  void _expand(double total) {
    if (_sqlHeight <= 0) {
      final maxSql =
          (total - _tabBarHeight - _resizeHandleHeight - _minContentHeight)
              .clamp(_minSqlHeight, double.infinity);
      _sqlHeight = (total * 0.45).clamp(_minSqlHeight, maxSql);
    }
    setState(() => _tabsExpanded = true);
  }

  void _collapse() => setState(() => _tabsExpanded = false);

  void _toggle(double total) => _tabsExpanded ? _collapse() : _expand(total);

  void _onResizeDrag(double dy, double total) {
    if (!_tabsExpanded) {
      _expand(total);
      return;
    }
    setState(() {
      final maxSql =
          (total - _tabBarHeight - _resizeHandleHeight - _minContentHeight)
              .clamp(_minSqlHeight, double.infinity);
      _sqlHeight = (_sqlHeight + dy).clamp(_minSqlHeight, maxSql);
    });
  }

  @override
  Widget build(BuildContext context) {
    final conn = ref.watch(activeConnectionProvider);
    if (conn == null) {
      return const Scaffold(
        body: Center(
          child: Text(
            '未打开连接',
            style: TextStyle(color: ShadTokens.mutedForeground),
          ),
        ),
      );
    }
    final view = ref.watch(workspaceViewProvider);
    final showTabs = view == WorkspaceView.tabs;
    final tab = ref.watch(workspaceTabProvider);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: ShadTokens.space4,
          title: Row(
            children: [
              const Icon(
                RemixIcons.server_line,
                size: 18,
                color: ShadTokens.primary,
              ),
              const SizedBox(width: ShadTokens.space2),
              Text(conn.name),
              const SizedBox(width: ShadTokens.space3),
              Text(
                '${conn.host}:${conn.port}',
                style: const TextStyle(
                  fontSize: ShadTokens.fontAux,
                  color: ShadTokens.mutedForeground,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: '新建数据库',
              onPressed: () => showCreateDatabaseSheet(context, ref),
              icon: const Icon(
                RemixIcons.play_list_add_line,
                size: 18,
                color: ShadTokens.mutedForeground,
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: '刷新',
              onPressed: () {
                ref.invalidate(connectionDatabaseListProvider(conn));
                ref.invalidate(databaseListProvider);
              },
              icon: const Icon(
                RemixIcons.refresh_line,
                size: 18,
                color: ShadTokens.mutedForeground,
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: '断开连接',
              onPressed: () => _disconnectConnectionAction(context, ref, conn),
              icon: const Icon(
                RemixIcons.link_unlink,
                size: 18,
                color: ShadTokens.mutedForeground,
              ),
            ),
            PopupMenuButton<_WorkspaceConnAction>(
              tooltip: '操作',
              icon: const Icon(
                RemixIcons.more_line,
                size: 18,
                color: ShadTokens.mutedForeground,
              ),
              onSelected: (action) => switch (action) {
                _WorkspaceConnAction.test => _testConnectionAction(
                  context,
                  ref,
                  conn,
                ),
                _WorkspaceConnAction.edit => showConnectionFormDialog(
                  context,
                  ref,
                  editing: conn,
                ),
                _WorkspaceConnAction.delete => _deleteConnectionAction(
                  context,
                  ref,
                  conn,
                ),
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _WorkspaceConnAction.test,
                  child: Text('测试连接'),
                ),
                PopupMenuItem(
                  value: _WorkspaceConnAction.edit,
                  child: Text('编辑连接'),
                ),
                PopupMenuItem(
                  value: _WorkspaceConnAction.delete,
                  child: Text('删除连接'),
                ),
              ],
            ),
            if (showTabs) ...[
              Container(width: 1, height: 24, color: ShadTokens.divider),
              const SizedBox(width: ShadTokens.space1),
              Padding(
                padding: const EdgeInsets.only(right: ShadTokens.space3),
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: '仪表盘',
                  onPressed: () =>
                      ref.read(workspaceViewProvider.notifier).showDashboard(),
                  icon: const Icon(
                    RemixIcons.speed_up_line,
                    size: 18,
                    color: ShadTokens.mutedForeground,
                  ),
                ),
              ),
            ],
          ],
        ),
        body: showTabs
            ? LayoutBuilder(
                builder: (context, constraints) {
                  final total = constraints.maxHeight;
                  final fixed = _tabBarHeight + _resizeHandleHeight;
                  final maxSql = (total - fixed - _minContentHeight).clamp(
                    _minSqlHeight,
                    double.infinity,
                  );
                  final sqlHeight = _tabsExpanded
                      ? _sqlHeight.clamp(_minSqlHeight, maxSql)
                      : total - fixed;
                  return Column(
                    children: [
                      SizedBox(
                        height: sqlHeight,
                        child: const SqlWorkbenchPage(),
                      ),
                      _WorkspaceResizeHandle(
                        onDrag: (dy) => _onResizeDrag(dy, total),
                      ),
                      SizedBox(
                        height: _tabBarHeight,
                        child: Material(
                          color: ShadTokens.card,
                          child: Row(
                            children: [
                              Expanded(
                                child: TabBar(
                                  onTap: (i) {
                                    ref
                                        .read(workspaceTabProvider.notifier)
                                        .select(i);
                                  },
                                  tabs: const [
                                    Tab(text: '表管理'),
                                    Tab(text: '用户与权限'),
                                    Tab(text: '数据浏览'),
                                  ],
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                tooltip: _tabsExpanded ? '收起' : '展开',
                                onPressed: () => _toggle(total),
                                icon: Icon(
                                  _tabsExpanded
                                      ? RemixIcons.arrow_down_s_line
                                      : RemixIcons.arrow_up_s_line,
                                  size: 18,
                                  color: ShadTokens.mutedForeground,
                                ),
                              ),
                              const SizedBox(width: ShadTokens.space2),
                            ],
                          ),
                        ),
                      ),
                      if (_tabsExpanded)
                        SizedBox(
                          height: (total - sqlHeight - fixed).clamp(
                            _minContentHeight,
                            double.infinity,
                          ),
                          child: IndexedStack(
                            index: tab,
                            children: const [
                              TablePage(),
                              UsersPage(),
                              DataBrowsePage(),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              )
            : const DashboardPage(),
      ),
    );
  }
}
