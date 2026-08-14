import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/query_result.dart';
import '../../../core/providers.dart';

/// 服务端版本：SHOW VERSION
final dashboardVersionProvider = FutureProvider<QueryResult>((ref) {
  return ref.watch(iotdbClientProvider).query('SHOW VERSION');
});

/// 区域信息：SHOW REGIONS
final dashboardRegionProvider = FutureProvider<QueryResult>((ref) {
  return ref.watch(iotdbClientProvider).query('SHOW REGIONS');
});

/// 测点总数：COUNT TIMESERIES
final dashboardTimeseriesCountProvider = FutureProvider<QueryResult>((ref) {
  return ref.watch(iotdbClientProvider).query('COUNT TIMESERIES');
});

/// 集群/节点信息：SHOW CLUSTER（NodeID/NodeType/Status/Host...）
final dashboardClusterProvider = FutureProvider<QueryResult>((ref) {
  return ref.watch(iotdbClientProvider).query('SHOW CLUSTER');
});

/// 检活延迟（毫秒）
final dashboardLatencyProvider = FutureProvider<int>((ref) {
  return ref.watch(iotdbClientProvider).ping();
});
