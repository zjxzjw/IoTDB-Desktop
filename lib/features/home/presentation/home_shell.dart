import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/models/connection.dart';
import '../../../core/models/metadata_node.dart';
import '../../../core/network/iotdb_client.dart';
import '../../../core/providers.dart';
import '../../../core/storage/app_settings_store.dart';
import '../../../core/theme/shadcn_tokens.dart';
import '../../../shared/confirm_dialog.dart';
import '../../connections/presentation/connection_form_sheet.dart';
import '../../connections/presentation/connection_sidebar.dart';
import '../../data/presentation/data_browse_page.dart';
import '../../dashboard/presentation/dashboard_page.dart';
import '../../database/presentation/database_page.dart';
import '../../sql/presentation/sql_workbench_page.dart';
import '../../users/presentation/users_page.dart';

/// 工作区「仪表盘」Tab 索引
const dashboardTabIndex = 4;

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
      final ms = await IotdbClient(conn).ping();
      ref.read(connectionStatusProvider.notifier).markSuccess(conn.id);
      ref.read(metadataSelectionProvider.notifier).clear();
      ref.read(activeConnectionProvider.notifier).set(conn);
      messenger.showSnackBar(
        SnackBar(content: Text('连接成功（${ms}ms），已进入工作区')),
      );
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
                    onDashboard: _noop,
                    onTest: _noop,
                    onEdit: _noop,
                    onDelete: _noop,
                    onSelectDatabase: _noopSelect,
                  ),
                  error: (e, _) => const ConnectionSidebar(
                    connections: [],
                    loading: false,
                    onOpen: _noop,
                    onDashboard: _noop,
                    onTest: _noop,
                    onEdit: _noop,
                    onDelete: _noop,
                    onSelectDatabase: _noopSelect,
                  ),
                  data: (list) => ConnectionSidebar(
                    connections: list,
                    loading: false,
                    onOpen: (c) => _openWorkspace(ref, c),
                    onDashboard: (c) => _openDashboard(ref, c),
                    onTest: (c) => _testConnection(context, ref, c),
                    onEdit: (c) =>
                        showConnectionFormDialog(context, ref, editing: c),
                    onDelete: (c) => _deleteConnection(context, ref, c),
                    onSelectDatabase: (c, node) =>
                        _selectDatabase(ref, c, node),
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

  static void _noopSelect(Connection c, MetaNode node) {}

  /// 点击侧栏数据库：激活对应连接，切到「数据库管理」并选中该数据库
  Future<void> _selectDatabase(
    WidgetRef ref,
    Connection conn,
    MetaNode node,
  ) async {
    final active = ref.read(activeConnectionProvider);
    if (active?.id != conn.id) {
      await _openWorkspace(ref, conn);
      if (ref.read(activeConnectionProvider)?.id != conn.id) return;
    }
    ref.read(workspaceTabProvider.notifier).select(0);
    ref.read(metadataSelectionProvider.notifier).select(node);
  }

  /// 点击侧栏仪表盘：未打开该连接时自动连接，然后切到「仪表盘」Tab
  Future<void> _openDashboard(WidgetRef ref, Connection conn) async {
    final active = ref.read(activeConnectionProvider);
    if (active?.id != conn.id) {
      await _openWorkspace(ref, conn);
      if (ref.read(activeConnectionProvider)?.id != conn.id) return;
    }
    ref.read(workspaceTabProvider.notifier).select(dashboardTabIndex);
  }

  Future<void> _testConnection(
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

  Future<void> _deleteConnection(
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
    if (confirmed) {
      await ref.read(connectionStoreProvider.notifier).remove(conn.id);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已删除连接')));
      }
    }
  }
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

/// 侧边栏右缘拖拽手柄：鼠标悬停显示调整光标，拖拽改变宽度
class _SidebarResizeHandle extends StatelessWidget {
  final VoidCallback onDragStart;
  final ValueChanged<double> onDrag;
  final VoidCallback onDragEnd;

  const _SidebarResizeHandle({
    required this.onDragStart,
    required this.onDrag,
    required this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) => onDragStart(),
        onHorizontalDragUpdate: (d) => onDrag(d.delta.dx),
        onHorizontalDragEnd: (_) => onDragEnd(),
        onHorizontalDragCancel: onDragEnd,
        child: Container(
          width: 6,
          color: Colors.transparent,
          child: Center(
            child: Container(
              width: 1,
              color: ShadTokens.border,
            ),
          ),
        ),
      ),
    );
  }
}

/// 工作区：Tab 容器（数据库管理 / SQL 工作台 / 用户与权限 / 数据浏览）
class WorkspaceScreen extends ConsumerStatefulWidget {
  const WorkspaceScreen({super.key});

  @override
  ConsumerState<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends ConsumerState<WorkspaceScreen> {
  @override
  Widget build(BuildContext context) {
    final conn = ref.watch(activeConnectionProvider);
    if (conn == null) {
      return const Scaffold(
        body: Center(
          child: Text('未打开连接', style: TextStyle(color: ShadTokens.mutedForeground)),
        ),
      );
    }
    final tab = ref.watch(workspaceTabProvider);
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: ShadTokens.space4,
          title: Row(
            children: [
              const Icon(
                RemixIcons.database_line,
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
            Padding(
              padding: const EdgeInsets.only(right: ShadTokens.space3),
              child: IconButton(
                tooltip: '返回连接管理',
                onPressed: () {
                  ref.read(activeConnectionProvider.notifier).clear();
                  ref.read(metadataSelectionProvider.notifier).clear();
                },
                icon: const Icon(RemixIcons.arrow_left_line, size: 18),
              ),
            ),
          ],
          bottom: TabBar(
            onTap: (i) =>
                ref.read(workspaceTabProvider.notifier).select(i),
            tabs: const [
              Tab(text: '数据库管理'),
              Tab(text: 'SQL 工作台'),
              Tab(text: '用户与权限'),
              Tab(text: '数据浏览'),
              Tab(text: '仪表盘'),
            ],
          ),
        ),
        body: IndexedStack(
          index: tab,
          children: const [
            DatabasePage(),
            SqlWorkbenchPage(),
            UsersPage(),
            DataBrowsePage(),
            DashboardPage(),
          ],
        ),
      ),
    );
  }
}
