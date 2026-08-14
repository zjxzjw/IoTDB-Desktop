import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/models/connection.dart';
import '../../../core/providers.dart';
import '../../../core/theme/shadcn_tokens.dart';
import '../../settings/presentation/settings_dialog.dart';
import 'connection_form_sheet.dart';

/// 侧边栏：连接列表 + 新建入口
class ConnectionSidebar extends ConsumerStatefulWidget {
  final List<Connection> connections;
  final bool loading;
  final ValueChanged<Connection> onOpen;
  final ValueChanged<Connection> onTest;
  final ValueChanged<Connection> onEdit;
  final ValueChanged<Connection> onDelete;

  const ConnectionSidebar({
    super.key,
    required this.connections,
    required this.loading,
    required this.onOpen,
    required this.onTest,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  ConsumerState<ConnectionSidebar> createState() => _ConnectionSidebarState();
}

class _ConnectionSidebarState extends ConsumerState<ConnectionSidebar> {
  @override
  Widget build(BuildContext context) {
    return Material(
      color: ShadTokens.sidebar,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: ShadTokens.border)),
        ),
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
                  fontWeight: FontWeight.w600
                )
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
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: ShadTokens.space2),
      itemCount: widget.connections.length,
      separatorBuilder: (_, _) => const SizedBox(height: 2),
      itemBuilder: (context, index) {
        final conn = widget.connections[index];
        return _ConnectionItem(
          conn: conn,
          active: conn.id == active?.id,
          onOpen: () => widget.onOpen(conn),
          onTest: () => widget.onTest(conn),
          onEdit: () => widget.onEdit(conn),
          onDelete: () => widget.onDelete(conn),
        );
      },
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

class _ConnectionItem extends StatelessWidget {
  final Connection conn;
  final bool active;
  final VoidCallback onOpen;
  final VoidCallback onTest;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ConnectionItem({
    required this.conn,
    required this.active,
    required this.onOpen,
    required this.onTest,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOpen,
      onDoubleTap: onOpen,
      borderRadius: BorderRadius.circular(ShadTokens.radiusDefault),
      hoverColor: ShadTokens.sidebarHover,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: ShadTokens.space3,
          vertical: ShadTokens.space3,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 8,
              height: 8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: active ? ShadTokens.success : ShadTokens.placeholder,
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
          ],
        ),
      ),
    );
  }
}
