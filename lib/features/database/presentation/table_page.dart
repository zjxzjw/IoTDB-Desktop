import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/models/table_meta.dart';
import '../../../core/providers.dart';
import '../../../core/theme/shadcn_tokens.dart';
import '../../../core/utils/sql_builder.dart';
import '../../../shared/confirm_dialog.dart';
import '../../../shared/empty_state.dart';
import '../data/database_providers.dart';
import 'add_column_form.dart';
import 'create_table_form.dart';
import 'ttl_dialog.dart';

/// 表管理页：数据库 → 表列表 → 表结构（列）详情
class TablePage extends ConsumerWidget {
  const TablePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseSelectionProvider);
    if (db == null) {
      return const Center(
        child: Text(
          '请先在左侧连接中选择数据库',
          style: TextStyle(
            fontSize: ShadTokens.fontBody,
            color: ShadTokens.placeholder,
          ),
        ),
      );
    }
    final table = ref.watch(tableSelectionProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(context, ref, db),
        const Divider(height: 1),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 280, child: _TableListPane(db: db)),
              const VerticalDivider(width: 1),
              Expanded(
                child: table == null
                    ? const EmptyState(
                        icon: RemixIcons.table_line,
                        title: '选择表查看结构',
                        description: '左侧选择表，右侧查看其列定义（TIME/TAG/ATTRIBUTE/FIELD）',
                      )
                    : _TableDetailPane(db: db, table: table),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    String db,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ShadTokens.space4,
        vertical: ShadTokens.space3,
      ),
      child: Row(
        children: [
          const Icon(
            RemixIcons.table_line,
            size: 16,
            color: ShadTokens.primary,
          ),
          const SizedBox(width: ShadTokens.space2),
          const Text(
            '表管理',
            style: TextStyle(
              fontSize: ShadTokens.fontTitle,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: ShadTokens.space2),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: ShadTokens.space2,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: ShadTokens.muted,
              borderRadius: BorderRadius.circular(ShadTokens.radiusDefault),
            ),
            child: Text(
              db,
              style: const TextStyle(
                fontSize: ShadTokens.fontAux,
                color: ShadTokens.mutedForeground,
              ),
            ),
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: () => showCreateTableSheet(context, ref, db: db),
            icon: const Icon(RemixIcons.add_line, size: 16),
            label: const Text('新建表'),
          ),
          const SizedBox(width: ShadTokens.space2),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: '刷新',
            onPressed: () => _refresh(ref, db),
            icon: const Icon(RemixIcons.refresh_line, size: 18),
          ),
        ],
      ),
    );
  }

  void _refresh(WidgetRef ref, String db) {
    ref.invalidate(tableListProvider(db));
    final table = ref.read(tableSelectionProvider);
    if (table != null) {
      ref.invalidate(columnListProvider(TableRef(db, table)));
    }
    final conn = ref.read(activeConnectionProvider);
    if (conn != null) {
      ref.invalidate(connectionTableListProvider(TableScope(conn, db)));
    }
  }
}

class _TableListPane extends ConsumerWidget {
  final String db;

  const _TableListPane({required this.db});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(tableListProvider(db));
    final selected = ref.watch(tableSelectionProvider);
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: result.when(
            loading: () => const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(ShadTokens.space4),
                child: Text(
                  '加载失败：$e',
                  style: const TextStyle(color: ShadTokens.destructive),
                ),
              ),
            ),
            data: (r) {
              final tables = parseTables(r, db);
              if (tables.isEmpty) {
                return const EmptyState(
                  icon: RemixIcons.table_line,
                  title: '暂无表',
                  description: '点击右上角「新建表」',
                );
              }
              return ListView.separated(
                itemCount: tables.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final t = tables[i];
                  final sel = t.name == selected;
                  return InkWell(
                    onTap: () {
                      ref
                          .read(databaseSelectionProvider.notifier)
                          .select(db);
                      ref.read(tableSelectionProvider.notifier).select(t.name);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: ShadTokens.space4,
                        vertical: ShadTokens.space2,
                      ),
                      color: sel
                          ? (isLight ? ShadTokens.muted : ShadTokens.mutedDark)
                          : null,
                      child: Row(
                        children: [
                          Icon(
                            RemixIcons.table_line,
                            size: 15,
                            color: sel
                                ? ShadTokens.primary
                                : ShadTokens.mutedForeground,
                          ),
                          const SizedBox(width: ShadTokens.space2),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.name,
                                  style: TextStyle(
                                    fontSize: ShadTokens.fontBody,
                                    fontWeight: sel
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: sel
                                        ? ShadTokens.primary
                                        : ShadTokens.foreground,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (t.comment != null && t.comment!.isNotEmpty)
                                  Text(
                                    t.comment!,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: ShadTokens.placeholder,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          if (t.status != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Text(
                                _statusLabel(t.status!),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _statusColor(t.status!),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  String _statusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'USING':
        return '可用';
      case 'PRE_CREATE':
        return '创建中';
      case 'PRE_DELETE':
        return '删除中';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'USING':
        return ShadTokens.success;
      case 'PRE_CREATE':
        return ShadTokens.warning;
      case 'PRE_DELETE':
        return ShadTokens.destructive;
      default:
        return ShadTokens.placeholder;
    }
  }
}

class _TableDetailPane extends ConsumerWidget {
  final String db;
  final String table;

  const _TableDetailPane({required this.db, required this.table});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final columns = ref.watch(columnListProvider(TableRef(db, table)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: ShadTokens.space4,
            vertical: ShadTokens.space3,
          ),
          child: Row(
            children: [
              const Icon(
                RemixIcons.table_2,
                size: 16,
                color: ShadTokens.primary,
              ),
              const SizedBox(width: ShadTokens.space2),
              Expanded(
                child: Text(
                  '$db.$table',
                  style: const TextStyle(
                    fontSize: ShadTokens.fontTitle,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  ref
                      .read(databaseSelectionProvider.notifier)
                      .select(db);
                  ref.read(tableSelectionProvider.notifier).select(table);
                  ref.read(workspaceViewProvider.notifier).showTabs();
                  ref.read(workspaceTabProvider.notifier).select(2);
                },
                icon: const Icon(RemixIcons.bar_chart_2_line, size: 16),
                label: const Text('数据浏览'),
              ),
              const SizedBox(width: ShadTokens.space2),
              FilledButton.tonalIcon(
                onPressed: () =>
                    showAddColumnSheet(context, ref, db: db, table: table),
                icon: const Icon(RemixIcons.add_circle_line, size: 16),
                label: const Text('新建列'),
              ),
              const SizedBox(width: ShadTokens.space2),
              OutlinedButton.icon(
                onPressed: () => showTtlDialog(
                  context,
                  ref,
                  target: TtlTarget.table,
                  db: db,
                  table: table,
                ),
                icon: const Icon(RemixIcons.time_line, size: 16),
                label: const Text('设置TTL'),
              ),
              const SizedBox(width: ShadTokens.space2),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: '删除表',
                onPressed: () => _dropTable(context, ref),
                icon: const Icon(
                  RemixIcons.delete_bin_line,
                  size: 18,
                  color: ShadTokens.destructive,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: columns.when(
            loading: () => const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(ShadTokens.space4),
                child: Text(
                  '加载失败：$e',
                  style: const TextStyle(color: ShadTokens.destructive),
                ),
              ),
            ),
            data: (r) {
              final cols = parseColumns(r);
              if (cols.isEmpty) {
                return const EmptyState(
                  icon: Icons.view_column_outlined,
                  title: '该表暂无列',
                  description: '点击「新建列」添加',
                );
              }
              return SingleChildScrollView(
                padding: const EdgeInsets.all(ShadTokens.space4),
                child: DataTable(
                  headingRowColor: WidgetStatePropertyAll(ShadTokens.muted),
                  horizontalMargin: ShadTokens.space4,
                  columnSpacing: ShadTokens.space4,
                  columns: const [
                    DataColumn(label: Text('列名')),
                    DataColumn(label: Text('类别')),
                    DataColumn(label: Text('数据类型')),
                    DataColumn(label: Text('状态')),
                    DataColumn(label: Text('注释')),
                    DataColumn(label: Text('')),
                  ],
                  rows: [
                    for (final col in cols)
                      DataRow(
                        cells: [
                          DataCell(
                            Text(
                              col.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              col.category.label,
                              style: TextStyle(
                                fontSize: 13,
                                color: _categoryColor(col.category),
                              ),
                            ),
                          ),
                          DataCell(Text(col.dataType)),
                          DataCell(
                            Text(
                              col.status == null ? '-' : col.status!,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          DataCell(
                            Text(
                              col.comment ?? '-',
                              style: const TextStyle(
                                fontSize: 13,
                                color: ShadTokens.mutedForeground,
                              ),
                            ),
                          ),
                          DataCell(
                            col.canDrop
                                ? IconButton(
                                    visualDensity: VisualDensity.compact,
                                    tooltip: '删除列',
                                    onPressed: () =>
                                        _dropColumn(context, ref, col),
                                    icon: const Icon(
                                      RemixIcons.delete_bin_line,
                                      size: 15,
                                      color: ShadTokens.destructive,
                                    ),
                                  )
                                : const Tooltip(
                                    message: 'TIME / TAG 列不可删除',
                                    child: Icon(
                                      RemixIcons.lock_line,
                                      size: 15,
                                      color: ShadTokens.textDisabled,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Color _categoryColor(ColumnCategory c) {
    return switch (c) {
      ColumnCategory.time => ShadTokens.primary,
      ColumnCategory.tag => ShadTokens.warning,
      ColumnCategory.attribute => ShadTokens.mutedForeground,
      ColumnCategory.field => ShadTokens.success,
    };
  }

  Future<void> _dropColumn(
    BuildContext context,
    WidgetRef ref,
    TableColumn col,
  ) async {
    final ok = await showConfirmDialog(
      context,
      title: '删除列',
      message: '确定删除列「${col.name}」？该列数据将被删除，不可恢复。',
      confirmText: '删除',
      confirmColor: ShadTokens.destructive,
    );
    if (!ok) return;
    try {
      await ref
          .read(iotdbClientProvider)
          .nonQuery(SqlBuilder.alterDropColumn(db, table, col.name));
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('列「${col.name}」已删除')));
      ref.invalidate(columnListProvider(TableRef(db, table)));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('删除失败：$e')));
    }
  }

  Future<void> _dropTable(BuildContext context, WidgetRef ref) async {
    final ok = await showConfirmDialog(
      context,
      title: '删除表',
      message: '确定删除表「$db.$table」？表内所有数据将被删除，不可恢复。',
      confirmText: '删除',
      confirmColor: ShadTokens.destructive,
    );
    if (!ok) return;
    try {
      await ref
          .read(iotdbClientProvider)
          .nonQuery(SqlBuilder.dropTable(db, table));
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('表已删除')));
      ref.read(tableSelectionProvider.notifier).clear();
      ref.invalidate(tableListProvider(db));
      final conn = ref.read(activeConnectionProvider);
      if (conn != null) {
        ref.invalidate(connectionTableListProvider(TableScope(conn, db)));
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('删除失败：$e')));
    }
  }
}
