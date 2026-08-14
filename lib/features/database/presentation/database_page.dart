import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/models/metadata_node.dart';
import '../../../core/providers.dart';
import '../../../core/theme/shadcn_tokens.dart';
import '../data/database_providers.dart';
import 'create_timeseries_form.dart';
import 'metadata_tree.dart';

/// 数据库管理页：仅展示当前所选数据库的「设备与测点」树
class DatabasePage extends ConsumerWidget {
  const DatabasePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(metadataSelectionProvider);
    final dbPath = _databaseOf(selected);
    if (dbPath == null) {
      return const Center(
        child: Text(
          '请先在左侧连接中选择数据库',
          style: TextStyle(fontSize: ShadTokens.fontBody, color: ShadTokens.placeholder),
        ),
      );
    }
    return _DatabaseDetailPanel(
      db: MetaNode(dbPath, MetaNodeType.database, const {}),
    );
  }

  /// 由选中节点推导数据库路径：数据库节点直接用，设备/测点取其路径前两段
  String? _databaseOf(MetaNode? node) {
    if (node == null) return null;
    if (node.type == MetaNodeType.database) return node.path;
    final parts = node.path.split('.');
    return parts.length >= 2 ? parts.sublist(0, 2).join('.') : null;
  }
}

/// 设备与测点面板：该数据库下的设备 → 测点（懒加载）
class _DatabaseDetailPanel extends ConsumerWidget {
  final MetaNode db;

  const _DatabaseDetailPanel({required this.db});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: ShadTokens.space4, vertical: ShadTokens.space3),
          child: Row(
            children: [
              const Icon(RemixIcons.server_line, size: 16, color: ShadTokens.primary),
              const SizedBox(width: ShadTokens.space2),
              const Text(
                '设备与测点',
                style: TextStyle(fontSize: ShadTokens.fontTitle, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => showCreateTimeseriesSheet(context, ref),
                icon: const Icon(RemixIcons.add_line, size: 16),
                label: const Text('新建测点'),
              ),
              const SizedBox(width: ShadTokens.space2),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: '刷新',
                onPressed: () => ref.invalidate(deviceListProvider(db.path)),
                icon: const Icon(RemixIcons.refresh_line, size: 18),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: MetadataTree(
            databases: [db],
            onTap: (node) =>
                ref.read(metadataSelectionProvider.notifier).select(node),
          ),
        ),
      ],
    );
  }
}
