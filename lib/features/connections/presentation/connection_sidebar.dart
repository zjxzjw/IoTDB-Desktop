import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';
import '../../../core/theme/tdesign_tokens.dart';
import '../../../core/models/connection.dart';
import 'connection_form_sheet.dart';

/// 侧边栏：连接列表 + 新建入口
class ConnectionSidebar extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: TdTokens.bgContainer,
        border: Border(right: BorderSide(color: TdTokens.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context, ref),
          const Divider(),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : connections.isEmpty
                    ? _buildEmpty(context, ref)
                    : _buildList(context, ref),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(TdTokens.space4, TdTokens.space3, TdTokens.space3, TdTokens.space3),
      child: Row(
        children: [
          const Icon(RemixIcons.database_2_line, size: 20, color: TdTokens.brand),
          const SizedBox(width: TdTokens.space2),
          const Expanded(
            child: Text(
              'IoTDB Desktop',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: TdTokens.fontTitle, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            onPressed: () => showConnectionFormSheet(context, ref),
            icon: const Icon(RemixIcons.add_line, size: 18),
            tooltip: '新建连接',
            color: TdTokens.brand,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, WidgetRef ref) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: TdTokens.space2),
      itemCount: connections.length,
      separatorBuilder: (_, _) => const SizedBox(height: 2),
      itemBuilder: (context, index) {
        final conn = connections[index];
        return _ConnectionItem(
          conn: conn,
          onOpen: () => onOpen(conn),
          onTest: () => onTest(conn),
          onEdit: () => onEdit(conn),
          onDelete: () => onDelete(conn),
        );
      },
    );
  }

  Widget _buildEmpty(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(RemixIcons.plug_line, size: 32, color: TdTokens.textPlaceholder),
          const SizedBox(height: TdTokens.space2),
          const Text('暂无连接', style: TextStyle(fontSize: 13, color: TdTokens.textPlaceholder)),
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
        padding: const EdgeInsets.symmetric(horizontal: TdTokens.space3, vertical: TdTokens.space3),
        child: Row(
          children: [
            const SizedBox(
              width: 8,
              height: 8,
              child: DecoratedBox(
                decoration: BoxDecoration(color: TdTokens.textPlaceholder, shape: BoxShape.circle),
              ),
            ),
            const SizedBox(width: TdTokens.space2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    conn.name,
                    style: const TextStyle(fontSize: TdTokens.fontBody, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${conn.host}:${conn.port}',
                    style: const TextStyle(fontSize: 12, color: TdTokens.textPlaceholder),
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
