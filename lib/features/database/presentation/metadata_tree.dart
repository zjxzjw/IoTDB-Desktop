import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/models/query_result.dart';
import '../../../core/theme/tdesign_tokens.dart';
import '../data/database_providers.dart';

enum MetaNodeType { database, device, timeseries }

/// 元数据树节点
class MetaNode {
  final String path;
  final MetaNodeType type;
  final Map<String, String> attrs;

  const MetaNode(this.path, this.type, [this.attrs = const {}]);

  String get name {
    final parts = path.split('.');
    return parts.isEmpty ? path : parts.last;
  }
}

/// 把 QueryResult 的行转成列名→值映射
Map<String, String> rowToAttrs(QueryResult result, List<dynamic> row) {
  final map = <String, String>{};
  for (var i = 0; i < result.columnNames.length && i < row.length; i++) {
    map[result.columnNames[i]] = row[i]?.toString() ?? 'null';
  }
  return map;
}

/// 元数据树：数据库 → 设备 → 测点（懒加载）
/// [databases] 根节点列表；[onTap] 点击设备/测点节点回调
class MetadataTree extends ConsumerWidget {
  final List<MetaNode> databases;
  final ValueChanged<MetaNode> onTap;

  const MetadataTree({super.key, required this.databases, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (databases.isEmpty) {
      return const Center(
        child: Text('暂无数据库', style: TextStyle(fontSize: TdTokens.fontAux, color: TdTokens.textPlaceholder)),
      );
    }
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: TdTokens.space2, vertical: TdTokens.space2),
      children: [
        for (final db in databases) _DatabaseNode(db: db, onTap: onTap),
      ],
    );
  }
}

class _DatabaseNode extends StatelessWidget {
  final MetaNode db;
  final ValueChanged<MetaNode> onTap;

  const _DatabaseNode({required this.db, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: TdTokens.space2),
        leading: const Icon(RemixIcons.database_2_line, size: 16, color: TdTokens.brand),
        title: Text(
          db.name,
          style: const TextStyle(fontSize: TdTokens.fontBody, fontWeight: FontWeight.w500),
          overflow: TextOverflow.ellipsis,
        ),
        childrenPadding: const EdgeInsets.only(left: TdTokens.space4),
        children: [_DeviceList(db: db.path, onTap: onTap)],
      ),
    );
  }
}

class _DeviceList extends ConsumerWidget {
  final String db;
  final ValueChanged<MetaNode> onTap;

  const _DeviceList({required this.db, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(deviceListProvider(db));
    return result.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(TdTokens.space3),
        child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(TdTokens.space2),
        child: Text(
          '加载失败：$e',
          style: const TextStyle(fontSize: TdTokens.fontAux, color: TdTokens.danger),
        ),
      ),
      data: (r) => r.rows.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(TdTokens.space2),
              child: Text('无设备', style: TextStyle(fontSize: TdTokens.fontAux, color: TdTokens.textPlaceholder)),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final row in r.rows)
                  _DeviceNode(device: MetaNode(row.first.toString(), MetaNodeType.device, rowToAttrs(r, row)), onTap: onTap),
              ],
            ),
    );
  }
}

class _DeviceNode extends StatelessWidget {
  final MetaNode device;
  final ValueChanged<MetaNode> onTap;

  const _DeviceNode({required this.device, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final aligned = device.attrs['IsAligned'];
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: TdTokens.space2),
        leading: const Icon(RemixIcons.server_line, size: 16, color: TdTokens.textSecondary),
        title: Text(device.name, style: const TextStyle(fontSize: TdTokens.fontBody), overflow: TextOverflow.ellipsis),
        subtitle: aligned == null
            ? null
            : Text(
                '对齐: $aligned',
                style: const TextStyle(fontSize: 11, color: TdTokens.textPlaceholder),
              ),
        childrenPadding: const EdgeInsets.only(left: TdTokens.space4),
        children: [_TimeseriesList(device: device.path, onTap: onTap)],
      ),
    );
  }
}

class _TimeseriesList extends ConsumerWidget {
  final String device;
  final ValueChanged<MetaNode> onTap;

  const _TimeseriesList({required this.device, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(timeseriesListProvider(device));
    return result.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(TdTokens.space3),
        child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(TdTokens.space2),
        child: Text(
          '加载失败：$e',
          style: const TextStyle(fontSize: TdTokens.fontAux, color: TdTokens.danger),
        ),
      ),
      data: (r) => r.rows.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(TdTokens.space2),
              child: Text('无测点', style: TextStyle(fontSize: TdTokens.fontAux, color: TdTokens.textPlaceholder)),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final row in r.rows)
                  ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: TdTokens.space2),
                    leading: const Icon(RemixIcons.pulse_line, size: 16, color: TdTokens.textSecondary),
                    title: Text(row.first.toString(), style: const TextStyle(fontSize: TdTokens.fontBody), overflow: TextOverflow.ellipsis),
                    onTap: () => onTap(MetaNode(row.first.toString(), MetaNodeType.timeseries, rowToAttrs(r, row))),
                  ),
              ],
            ),
    );
  }
}
