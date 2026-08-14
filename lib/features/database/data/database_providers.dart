import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/query_result.dart';
import '../../../core/providers.dart';

/// 设备列表：SHOW DEVICES `<db>.**` WITH DATABASE
/// 注：2.0.10 实测必须带 `.**` 通配，`SHOW DEVICES <db>` 返回空
final deviceListProvider = FutureProvider.family<QueryResult, String>((ref, db) {
  return ref.watch(iotdbClientProvider).query('SHOW DEVICES $db.** WITH DATABASE');
});

/// 测点列表：SHOW TIMESERIES `<device>`.**（device 为完整设备路径）
final timeseriesListProvider = FutureProvider.family<QueryResult, String>((ref, device) {
  return ref.watch(iotdbClientProvider).query('SHOW TIMESERIES $device.**');
});
