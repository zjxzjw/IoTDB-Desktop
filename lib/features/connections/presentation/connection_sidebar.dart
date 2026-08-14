import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/models/connection.dart';
import '../../../core/theme/tdesign_tokens.dart';
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
  static const double _collapsedWidth = 48;

  bool _collapsed = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _collapsed ? _collapsedWidth : 280,
      decoration: BoxDecoration(
        color: TdTokens.bgContainer,
        border: Border(right: BorderSide(color: TdTokens.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context, ref),
          if (!_collapsed) ...[
            const Divider(),
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
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    if (_collapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: TdTokens.space3),
        child: IconButton(
          onPressed: () => setState(() => _collapsed = false),
          icon: const Icon(RemixIcons.menu_unfold_line, size: 18),
          tooltip: '展开侧边栏',
          color: TdTokens.textSecondary,
          visualDensity: VisualDensity.compact,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TdTokens.space4,
        TdTokens.space3,
        TdTokens.space3,
        TdTokens.space3,
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text.rich(
              TextSpan(text: 'IoTDB Desktop'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _collapsed = true),
            icon: const Icon(RemixIcons.menu_fold_line, size: 18),
            tooltip: '收起侧边栏',
            color: TdTokens.textSecondary,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, WidgetRef ref) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: TdTokens.space2),
      itemCount: widget.connections.length,
      separatorBuilder: (_, _) => const SizedBox(height: 2),
      itemBuilder: (context, index) {
        final conn = widget.connections[index];
        return _ConnectionItem(
          conn: conn,
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
            color: TdTokens.textPlaceholder,
          ),
          const SizedBox(height: TdTokens.space2),
          const Text(
            '暂无连接',
            style: TextStyle(fontSize: 13, color: TdTokens.textPlaceholder),
          ),
          const SizedBox(height: TdTokens.space3),
          TextButton.icon(
            onPressed: () => showConnectionFormSheet(context, ref),
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
  final VoidCallback onOpen;
  final VoidCallback onTest;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ConnectionItem({
    required this.conn,
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
      borderRadius: BorderRadius.circular(TdTokens.radiusDefault),
      hoverColor: TdTokens.bgHover,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TdTokens.space3,
          vertical: TdTokens.space3,
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 8,
              height: 8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: TdTokens.textPlaceholder,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: TdTokens.space2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    conn.name,
                    style: const TextStyle(
                      fontSize: TdTokens.fontBody,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${conn.host}:${conn.port}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: TdTokens.textPlaceholder,
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
