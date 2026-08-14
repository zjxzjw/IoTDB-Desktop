import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/models/metadata_node.dart';
import '../../../core/models/query_result.dart';
import '../../../core/providers.dart';
import '../../../core/theme/shadcn_tokens.dart';
import '../../../core/utils/sql_builder.dart';
import '../../../shared/confirm_dialog.dart';
import '../../../shared/result_table.dart';
import '../data/database_providers.dart';
import 'create_database_form.dart';
import 'create_timeseries_form.dart';
import 'metadata_tree.dart';
import 'ttl_dialog.dart';

/// 数据库管理页：左侧元数据树 + 右侧详情面板
class DatabasePage extends ConsumerStatefulWidget {
  const DatabasePage({super.key});

  @override
  ConsumerState<DatabasePage> createState() => _DatabasePageState();
}

class _DatabasePageState extends ConsumerState<DatabasePage> {
  void _onNodeTap(MetaNode node) =>
      ref.read(metadataSelectionProvider.notifier).select(node);

  void _clearSelection() =>
      ref.read(metadataSelectionProvider.notifier).clear();

  @override
  Widget build(BuildContext context) {
    final databases = ref.watch(databaseListProvider);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 320,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTreeHeader(),
              const Divider(height: 1),
              Expanded(
                child: databases.when(
                  loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  error: (e, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(ShadTokens.space4),
                      child: Text('加载失败：$e', style: const TextStyle(color: ShadTokens.destructive)),
                    ),
                  ),
                  data: (r) => MetadataTree(
                    databases: [
                      for (final row in r.rows)
                        MetaNode(row.first.toString(), MetaNodeType.database, rowToAttrs(r, row)),
                    ],
                    onTap: _onNodeTap,
                  ),
                ),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(child: _buildDetailPanel()),
      ],
    );
  }

  Widget _buildTreeHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ShadTokens.space4, vertical: ShadTokens.space3),
      child: Row(
        children: [
          const Icon(RemixIcons.tree_line, size: 16, color: ShadTokens.primary),
          const SizedBox(width: ShadTokens.space2),
          const Text(
            '元数据',
            style: TextStyle(fontSize: ShadTokens.fontTitle, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: '刷新元数据',
            onPressed: () {
              final active = ref.read(activeConnectionProvider);
              if (active != null) {
                ref.invalidate(connectionDatabaseListProvider(active));
              }
              ref.invalidate(databaseListProvider);
              _clearSelection();
            },
            icon: const Icon(RemixIcons.refresh_line, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailPanel() {
    final selected = ref.watch(metadataSelectionProvider);
    if (selected == null) {
      return const _DatabaseListPanel();
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: ShadTokens.space4, vertical: ShadTokens.space3),
          child: Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: '返回数据库列表',
                onPressed: _clearSelection,
                icon: const Icon(RemixIcons.arrow_left_line, size: 18),
              ),
              const SizedBox(width: ShadTokens.space2),
              Expanded(
                child: Text(
                  selected.path,
                  style: const TextStyle(fontSize: ShadTokens.fontTitle, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (selected.type == MetaNodeType.device) ...[
                const SizedBox(width: ShadTokens.space2),
                FilledButton.icon(
                  onPressed: () => showCreateTimeseriesSheet(context, ref, devicePrefix: selected.path),
                  icon: const Icon(RemixIcons.add_line, size: 16),
                  label: const Text('新建测点'),
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: switch (selected.type) {
            MetaNodeType.database => _DatabaseDetailPanel(db: selected),
            MetaNodeType.device => _DevicePanel(device: selected),
            MetaNodeType.timeseries => _TimeseriesDetail(node: selected, onDeleted: _clearSelection),
          },
        ),
      ],
    );
  }
}

/// 数据库详情面板：该数据库下的设备 → 测点（懒加载）
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

/// 数据库列表表格 + 工具栏
class _DatabaseListPanel extends ConsumerWidget {
  const _DatabaseListPanel();

  Future<void> _deleteDatabase(BuildContext context, WidgetRef ref, String name) async {
    final ok = await showConfirmDialog(
      context,
      title: '删除数据库',
      message: '确定删除数据库「$name」？该操作将删除其中全部数据，不可恢复。',
      confirmText: '删除',
      confirmColor: ShadTokens.destructive,
    );
    if (!ok) return;
    try {
      await ref.read(iotdbClientProvider).nonQuery(SqlBuilder.dropDatabase(name));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('数据库已删除')));
      }
      ref.invalidate(databaseListProvider);
      final active = ref.read(activeConnectionProvider);
      if (active != null) {
        ref.invalidate(connectionDatabaseListProvider(active));
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('删除失败：$e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(databaseListProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: ShadTokens.space4, vertical: ShadTokens.space3),
          child: Row(
            children: [
              const Icon(RemixIcons.database_2_line, size: 16, color: ShadTokens.primary),
              const SizedBox(width: ShadTokens.space2),
              const Text(
                '数据库',
                style: TextStyle(fontSize: ShadTokens.fontTitle, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () => showCreateDatabaseSheet(context, ref),
                icon: const Icon(RemixIcons.add_line, size: 16),
                label: const Text('新建数据库'),
              ),
              const SizedBox(width: ShadTokens.space2),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: '刷新',
                onPressed: () => ref.invalidate(databaseListProvider),
                icon: const Icon(RemixIcons.refresh_line, size: 18),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: result.when(
            loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            error: (e, _) => Center(child: Text('加载失败：$e', style: const TextStyle(color: ShadTokens.destructive))),
            data: (r) => _DatabaseTable(result: r, onDelete: (n) => _deleteDatabase(context, ref, n)),
          ),
        ),
      ],
    );
  }
}

class _DatabaseTable extends ConsumerWidget {
  final QueryResult result;
  final ValueChanged<String> onDelete;

  const _DatabaseTable({required this.result, required this.onDelete});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final columns = [...result.columnNames, ''];
    final dbCol = 0;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          headingRowColor: WidgetStatePropertyAll(ShadTokens.muted),
          horizontalMargin: ShadTokens.space4,
          columnSpacing: ShadTokens.space4,
          columns: [for (final name in columns) DataColumn(label: Text(name))],
          rows: [
            for (final row in result.rows)
              DataRow(
                cells: [
                  for (var i = 0; i < result.columnNames.length; i++)
                    DataCell(
                      Text(
                        i < row.length ? '${row[i]}' : '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: 'TTL',
                          icon: const Icon(RemixIcons.timer_line, size: 16),
                          onPressed: () => showTtlDialog(context, ref, database: '${row[dbCol]}'),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: '删除',
                          icon: const Icon(RemixIcons.delete_bin_line, size: 16, color: ShadTokens.destructive),
                          onPressed: () => onDelete('${row[dbCol]}'),
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
  }
}

/// 设备面板：该设备下的测点表格
class _DevicePanel extends ConsumerWidget {
  final MetaNode device;

  const _DevicePanel({required this.device});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(timeseriesListProvider(device.path));
    return result.when(
      loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (e, _) => Center(child: Text('加载失败：$e', style: const TextStyle(color: ShadTokens.destructive))),
      data: (r) => ResultTable(columns: r.columnNames, rows: r.rows, elapsedMs: r.elapsedMs),
    );
  }
}

/// 测点详情面板
class _TimeseriesDetail extends ConsumerWidget {
  final MetaNode node;
  final VoidCallback onDeleted;

  const _TimeseriesDetail({required this.node, required this.onDeleted});

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showConfirmDialog(
      context,
      title: '删除测点',
      message: '确定删除测点「${node.path}」？',
      confirmText: '删除',
      confirmColor: ShadTokens.destructive,
    );
    if (!ok) return;
    try {
      await ref.read(iotdbClientProvider).nonQuery(SqlBuilder.deleteTimeseries([node.path]));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('测点已删除')));
      }
      onDeleted();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('删除失败：$e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(ShadTokens.space4),
            children: [
              Text(node.path, style: const TextStyle(fontSize: ShadTokens.fontTitle, fontWeight: FontWeight.w600)),
              const SizedBox(height: ShadTokens.space4),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(ShadTokens.space4),
                  child: Column(
                    children: [
                      for (final entry in node.attrs.entries)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 140,
                                child: Text(
                                  entry.key,
                                  style: const TextStyle(color: ShadTokens.mutedForeground),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  entry.value,
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(ShadTokens.space3),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: ShadTokens.divider)),
            color: ShadTokens.card,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () => _delete(context, ref),
                icon: const Icon(RemixIcons.delete_bin_line, size: 16),
                label: const Text('删除测点'),
                style: OutlinedButton.styleFrom(foregroundColor: ShadTokens.destructive),
              ),
            ],
          ),
        ),
      ],
    );
  }
}