import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/models/metadata_node.dart';
import '../../../core/models/query_result.dart';
import '../../../core/providers.dart';
import '../../../core/theme/shadcn_tokens.dart';
import '../data/dashboard_providers.dart';

/// 仪表盘：服务概览统计卡片 + 数据库列表
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  void _refresh(WidgetRef ref) {
    ref.invalidate(dashboardVersionProvider);
    ref.invalidate(dashboardRegionProvider);
    ref.invalidate(dashboardTimeseriesCountProvider);
    ref.invalidate(dashboardClusterProvider);
    ref.invalidate(dashboardLatencyProvider);
    ref.invalidate(databaseListProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final databases = ref.watch(databaseListProvider);
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
                RemixIcons.speed_up_line,
                size: 16,
                color: ShadTokens.primary,
              ),
              const SizedBox(width: ShadTokens.space2),
              const Text(
                '仪表盘',
                style: TextStyle(
                  fontSize: ShadTokens.fontTitle,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: '刷新',
                onPressed: () => _refresh(ref),
                icon: const Icon(RemixIcons.refresh_line, size: 18),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(ShadTokens.space4),
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  const spacing = ShadTokens.space3;
                  final cardWidth =
                      (constraints.maxWidth - spacing * 4) / 5;
                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: [
                      _StatCard(
                        width: cardWidth,
                        title: '服务版本',
                        icon: RemixIcons.leaf_line,
                        result: ref.watch(dashboardVersionProvider),
                        valueOf: (r) => r.rows.isNotEmpty &&
                                r.rows.first.isNotEmpty
                            ? '${r.rows.first.first}'
                            : '—',
                      ),
                      _StatCard(
                        width: cardWidth,
                        title: '数据库数量',
                        icon: RemixIcons.database_2_line,
                        result: databases,
                        valueOf: (r) => '${r.rows.length}',
                      ),
                      _StatCard(
                        width: cardWidth,
                        title: '测点总数',
                        icon: RemixIcons.line_chart_line,
                        result: ref.watch(dashboardTimeseriesCountProvider),
                        valueOf: (r) => r.rows.isNotEmpty &&
                                r.rows.first.isNotEmpty
                            ? '${r.rows.first.first}'
                            : '—',
                      ),
                      _StatCard(
                        width: cardWidth,
                        title: '区域数量',
                        icon: RemixIcons.server_line,
                        result: ref.watch(dashboardRegionProvider),
                        valueOf: (r) => '${r.rows.length}',
                      ),
                      _StatusCard(width: cardWidth),
                    ],
                  );
                },
              ),
              const SizedBox(height: ShadTokens.space6),
              _buildServerSection(context, ref),
              const SizedBox(height: ShadTokens.space6),
              _buildDatabaseSection(context, ref, databases),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildServerSection(BuildContext context, WidgetRef ref) {
    final cluster = ref.watch(dashboardClusterProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '服务信息',
          style: TextStyle(
            fontSize: ShadTokens.fontBody,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: ShadTokens.space3),
        cluster.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(ShadTokens.space4),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (e, _) => Text(
            '加载失败：$e',
            style: const TextStyle(color: ShadTokens.destructive),
          ),
          data: (r) => r.rows.isEmpty
              ? const Text(
                  '无节点信息',
                  style: TextStyle(color: ShadTokens.placeholder),
                )
              : _ClusterTable(result: r),
        ),
      ],
    );
  }

  Widget _buildDatabaseSection(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<QueryResult> databases,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '数据库列表',
          style: TextStyle(
            fontSize: ShadTokens.fontBody,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: ShadTokens.space3),
        databases.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(ShadTokens.space4),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (e, _) => Text(
            '加载失败：$e',
            style: const TextStyle(color: ShadTokens.destructive),
          ),
          data: (r) => r.rows.isEmpty
              ? const Text(
                  '无数据库',
                  style: TextStyle(color: ShadTokens.placeholder),
                )
              : _DatabaseTable(
                  result: r,
                  onSelect: (row) {
                    final node = MetaNode(
                      row.first.toString(),
                      MetaNodeType.database,
                      rowToAttrs(r, row),
                    );
                    ref.read(metadataSelectionProvider.notifier).select(node);
                    ref.read(workspaceViewProvider.notifier).showTabs();
                    ref.read(workspaceTabProvider.notifier).select(0);
                  },
                ),
        ),
      ],
    );
  }
}

/// 统计卡片：独立 loading / error / data
class _StatCard extends StatelessWidget {
  final double width;
  final String title;
  final IconData icon;
  final AsyncValue<QueryResult> result;
  final String Function(QueryResult) valueOf;

  const _StatCard({
    required this.width,
    required this.title,
    required this.icon,
    required this.result,
    required this.valueOf,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Container(
      width: width,
      padding: const EdgeInsets.all(ShadTokens.space4),
      decoration: BoxDecoration(
        color: isLight ? ShadTokens.card : ShadTokens.cardDark,
        border: Border.all(color: ShadTokens.border),
        borderRadius: BorderRadius.circular(ShadTokens.radiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: ShadTokens.primary),
              const SizedBox(width: ShadTokens.space2),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: ShadTokens.fontBody,
                    color: ShadTokens.mutedForeground,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: ShadTokens.space3),
          result.when(
            loading: () => const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            error: (e, _) => Text(
              '加载失败',
              style: const TextStyle(
                fontSize: ShadTokens.fontAux,
                color: ShadTokens.destructive,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            data: (r) => Text(
              valueOf(r),
              style: const TextStyle(
                fontSize: ShadTokens.fontPage,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// 网络延迟卡片：ping 延迟 + 按延迟等级着色的状态圆点
class _StatusCard extends ConsumerWidget {
  final double width;

  const _StatusCard({required this.width});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latency = ref.watch(dashboardLatencyProvider);
    final isLight = Theme.of(context).brightness == Brightness.light;

    final Color statusColor;
    final String statusText;
    switch (latency) {
      case AsyncData<int>(:final value):
        statusText = '${value}ms';
        if (value < 100) {
          statusColor = ShadTokens.success;
        } else if (value < 500) {
          statusColor = ShadTokens.warning;
        } else {
          statusColor = ShadTokens.destructive;
        }
      case AsyncError():
        statusColor = ShadTokens.destructive;
        statusText = '连接异常';
      case _:
        statusColor = ShadTokens.placeholder;
        statusText = '检测中…';
    }

    return Container(
      width: width,
      padding: const EdgeInsets.all(ShadTokens.space4),
      decoration: BoxDecoration(
        color: isLight ? ShadTokens.card : ShadTokens.cardDark,
        border: Border.all(color: ShadTokens.border),
        borderRadius: BorderRadius.circular(ShadTokens.radiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                RemixIcons.wifi_line,
                size: 16,
                color: ShadTokens.primary,
              ),
              SizedBox(width: ShadTokens.space2),
              Expanded(
                child: Text(
                  '网络延迟',
                  style: TextStyle(
                    fontSize: ShadTokens.fontBody,
                    color: ShadTokens.mutedForeground,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: ShadTokens.space3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: ShadTokens.space2),
              Flexible(
                child: Text(
                  statusText,
                  style: const TextStyle(
                    fontSize: ShadTokens.fontPage,
                    fontWeight: FontWeight.w600,
                    height: 1.0,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 集群/服务器节点表格（NodeID / 节点类型 / 状态 / 主机）
class _ClusterTable extends StatelessWidget {
  final QueryResult result;

  const _ClusterTable({required this.result});

  int? _columnIndex(String name) {
    for (var i = 0; i < result.columnNames.length; i++) {
      if (result.columnNames[i].toLowerCase() == name) return i;
    }
    return null;
  }

  String _cell(int col, List<dynamic> row) =>
      col >= 0 && col < row.length ? '${row[col]}' : '';

  @override
  Widget build(BuildContext context) {
    final idCol = _columnIndex('nodeid') ?? 0;
    final typeCol = _columnIndex('nodetype');
    final statusCol = _columnIndex('status');
    final hostCol = _columnIndex('host');
    final internalIpCol = _columnIndex('internalip');

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: ShadTokens.border),
        borderRadius: BorderRadius.circular(ShadTokens.radiusMedium),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              headingRowColor: WidgetStatePropertyAll(
                ShadTokens.mutedLighter,
              ),
              horizontalMargin: ShadTokens.space4,
              columnSpacing: ShadTokens.space4,
              columns: [
                const DataColumn(label: Text('节点 ID')),
                if (typeCol != null) const DataColumn(label: Text('节点类型')),
                if (statusCol != null) const DataColumn(label: Text('状态')),
                if (hostCol != null) const DataColumn(label: Text('主机地址')),
                if (internalIpCol != null)
                  const DataColumn(label: Text('内部地址')),
              ],
              rows: [
                for (final row in result.rows)
                  DataRow(
                    cells: [
                      DataCell(
                        Text(
                          _cell(idCol, row),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (typeCol != null)
                        DataCell(
                          Text(
                            _cell(typeCol, row),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      if (statusCol != null)
                        DataCell(
                          Builder(
                            builder: (context) {
                              final status = _cell(statusCol, row)
                                  .toLowerCase();
                              final color = status == 'running'
                                  ? ShadTokens.success
                                  : ShadTokens.destructive;
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: ShadTokens.space2),
                                  Text(_cell(statusCol, row)),
                                ],
                              );
                            },
                          ),
                        ),
                      if (hostCol != null)
                        DataCell(
                          Text(
                            _cell(hostCol, row),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      if (internalIpCol != null)
                        DataCell(
                          Text(
                            _cell(internalIpCol, row),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 数据库列表表格（名称 + TTL），点击行选中并进入 Tab 工作区
class _DatabaseTable extends StatelessWidget {
  final QueryResult result;
  final ValueChanged<List<dynamic>> onSelect;

  const _DatabaseTable({required this.result, required this.onSelect});

  int? _columnIndex(String name) {
    for (var i = 0; i < result.columnNames.length; i++) {
      if (result.columnNames[i].toLowerCase() == name) return i;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final dbCol = _columnIndex('database') ?? 0;
    final ttlCol = _columnIndex('ttl');
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: ShadTokens.border),
        borderRadius: BorderRadius.circular(ShadTokens.radiusMedium),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              headingRowColor: WidgetStatePropertyAll(
                ShadTokens.mutedLighter,
              ),
              horizontalMargin: ShadTokens.space4,
              columnSpacing: ShadTokens.space4,
              showCheckboxColumn: false,
              columns: [
                const DataColumn(label: Text('数据库')),
                if (ttlCol != null) const DataColumn(label: Text('TTL')),
              ],
              rows: [
                for (final row in result.rows)
                  DataRow(
                    onSelectChanged: (_) => onSelect(row),
                    cells: [
                      DataCell(
                        Text(
                          dbCol < row.length ? '${row[dbCol]}' : '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (ttlCol != null)
                        DataCell(
                          Text(
                            ttlCol < row.length ? '${row[ttlCol]}' : '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
