import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/query_result.dart';
import '../../../core/providers.dart';
import '../../../core/utils/sql_builder.dart';

/// 服务端版本：SHOW VERSION
final dashboardVersionProvider = FutureProvider<QueryResult>((ref) {
  return ref.watch(iotdbClientProvider).query('SHOW VERSION');
});

/// 区域信息：SHOW REGIONS
final dashboardRegionProvider = FutureProvider<QueryResult>((ref) {
  return ref.watch(iotdbClientProvider).query('SHOW REGIONS');
});

/// 表总数：遍历各库 SHOW TABLES FROM `<db>` 求和（跳过系统库与失败项）
final dashboardTableCountProvider = FutureProvider<int>((ref) async {
  final client = ref.watch(iotdbClientProvider);
  final List<dynamic> dbs;
  try {
    dbs = (await client.query('SHOW DATABASES')).rows;
  } catch (_) {
    return 0;
  }
  var total = 0;
  for (final row in dbs) {
    if (row.isEmpty) continue;
    final db = row.first.toString();
    if (db.toLowerCase().contains('information_schema')) continue;
    try {
      final r = await client.query('SHOW TABLES FROM ${SqlBuilder.ident(db)}');
      total += r.rows.length;
    } catch (_) {}
  }
  return total;
});

/// 集群/节点信息：SHOW CLUSTER（NodeID/NodeType/Status/Host...）
final dashboardClusterProvider = FutureProvider<QueryResult>((ref) {
  return ref.watch(iotdbClientProvider).query('SHOW CLUSTER');
});

/// 检活延迟（毫秒）
final dashboardLatencyProvider = FutureProvider<int>((ref) {
  return ref.watch(iotdbClientProvider).ping();
});
