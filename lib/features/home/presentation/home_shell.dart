import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/models/connection.dart';
import '../../../core/network/iotdb_client.dart';
import '../../../core/providers.dart';
import '../../../core/theme/tdesign_tokens.dart';
import '../../../shared/confirm_dialog.dart';
import '../../../shared/empty_state.dart';
import '../../connections/presentation/connection_form_sheet.dart';
import '../../connections/presentation/connection_sidebar.dart';
import '../../database/presentation/database_page.dart';

/// 应用外壳：左侧连接侧边栏 + 右侧内容区
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  Future<void> _openWorkspace(BuildContext context, WidgetRef ref, Connection conn) async {
    ref.read(activeConnectionProvider.notifier).set(conn);
    if (context.mounted) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WorkspaceScreen()));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Row(
        children: [
          ref.watch(connectionStoreProvider).when(
                loading: () => const ConnectionSidebar(
                  connections: [],
                  loading: true,
                  onOpen: _noop,
                  onTest: _noop,
                  onEdit: _noop,
                  onDelete: _noop,
                ),
                error: (e, _) => const ConnectionSidebar(
                  connections: [],
                  loading: false,
                  onOpen: _noop,
                  onTest: _noop,
                  onEdit: _noop,
                  onDelete: _noop,
                ),
                data: (list) => ConnectionSidebar(
                  connections: list,
                  loading: false,
                  onOpen: (c) => _openWorkspace(context, ref, c),
                  onTest: (c) => _testConnection(context, ref, c),
                  onEdit: (c) => showConnectionFormSheet(context, ref, editing: c),
                  onDelete: (c) => _deleteConnection(context, ref, c),
                ),
              ),
          const VerticalDivider(width: 1),
          const Expanded(child: _WelcomePane()),
        ],
      ),
    );
  }

  static void _noop(Connection c) {}

  Future<void> _testConnection(BuildContext context, WidgetRef ref, Connection conn) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final client = IotdbClient(conn);
      final ms = await client.ping();
      String version = '';
      try {
        final r = await client.query('SHOW VERSION');
        version = r.rows.isNotEmpty ? '${r.rows.first.first}' : '';
      } catch (_) {}
      messenger.showSnackBar(
        SnackBar(content: Text('连接成功（${ms}ms）${version.isEmpty ? '' : '，服务端版本 $version'}')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _deleteConnection(BuildContext context, WidgetRef ref, Connection conn) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '删除连接',
      message: '确定删除连接「${conn.name}」？该操作不可恢复。',
      confirmText: '删除',
      confirmColor: TdTokens.danger,
    );
    if (confirmed) {
      await ref.read(connectionStoreProvider.notifier).remove(conn.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已删除连接')));
      }
    }
  }
}

class _WelcomePane extends ConsumerWidget {
  const _WelcomePane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(connectionStoreProvider).value ?? const <Connection>[];
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(RemixIcons.database_2_line, size: 48, color: TdTokens.brand),
          const SizedBox(height: TdTokens.space4),
          Text(
            list.isEmpty ? '欢迎使用 IoTDB Desktop' : '选择一个连接开始管理',
            style: const TextStyle(fontSize: TdTokens.fontPage, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: TdTokens.space2),
          const Text(
            '左侧管理 IoTDB REST 连接，双击或点击连接进入工作区',
            style: TextStyle(fontSize: 13, color: TdTokens.textSecondary),
          ),
        ],
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
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final conn = ref.watch(activeConnectionProvider);
    if (conn == null) {
      return const Scaffold(
        body: Center(child: Text('未打开连接', style: TextStyle(color: TdTokens.textSecondary))),
      );
    }
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: TdTokens.space4,
          title: Row(
            children: [
              const Icon(RemixIcons.database_line, size: 18, color: TdTokens.brand),
              const SizedBox(width: TdTokens.space2),
              Text(conn.name),
              const SizedBox(width: TdTokens.space3),
              Text(
                '${conn.host}:${conn.port}',
                style: const TextStyle(fontSize: TdTokens.fontAux, color: TdTokens.textSecondary, fontWeight: FontWeight.w400),
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: TdTokens.space3),
              child: IconButton(
                tooltip: '返回连接管理',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(RemixIcons.arrow_left_line, size: 18),
              ),
            ),
          ],
          bottom: TabBar(
            onTap: (i) => setState(() => _tab = i),
            tabs: const [
              Tab(text: '数据库管理'),
              Tab(text: 'SQL 工作台'),
              Tab(text: '用户与权限'),
              Tab(text: '数据浏览'),
            ],
          ),
        ),
        body: IndexedStack(
          index: _tab,
          children: const [
            DatabasePage(),
            _PlaceholderTab(icon: RemixIcons.code_box_line, message: 'SQL 编辑器、高亮与结果表格将在 M3 迭代开放'),
            _PlaceholderTab(icon: RemixIcons.user_settings_line, message: '用户/角色/权限编辑器将在 M4 迭代开放'),
            _PlaceholderTab(icon: RemixIcons.bar_chart_2_line, message: '数据分页预览与图表将在 M5 迭代开放'),
          ],
        ),
      ),
    );
  }
}

/// 未实现模块的占位页
class _PlaceholderTab extends StatelessWidget {
  final IconData icon;
  final String message;

  const _PlaceholderTab({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: icon,
      title: message,
      description: '当前版本暂未开放',
    );
  }
}