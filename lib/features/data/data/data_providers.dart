import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/query_result.dart';
import '../../../core/providers.dart';

/// 数据浏览查询参数（family 键：任一字段变化自动重建查询）
class DataQuery {
  final String device; // 完整设备路径，如 root.工厂.d1
  final String timeseries; // 完整测点路径，如 root.工厂.d1.s1
  final int startMs;
  final int endMs;
  final String interval; // 聚合窗口，如 5m / 1h（自动模式由服务端换算传入）
  final String aggregate; // avg（数值型）/ count（TEXT/BOOLEAN 等）
  final int page; // 原始数据分页（0 起）
  final int pageSize;

  const DataQuery({
    required this.device,
    required this.timeseries,
    required this.startMs,
    required this.endMs,
    required this.interval,
    required this.aggregate,
    this.page = 0,
    this.pageSize = 100,
  });

  String get sensorName => timeseries.split('.').last;

  /// SELECT 原始数据（服务端分页）
  String get rawSql =>
      'SELECT $sensorName FROM $device WHERE time >= $startMs AND time <= $endMs '
      'LIMIT $pageSize OFFSET ${page * pageSize}';

  /// 时间窗内总行数
  String get countSql =>
      'SELECT count($sensorName) FROM $device WHERE time >= $startMs AND time <= $endMs';

  /// 聚合查询（图表降采样）：GROUP BY 必须带 [start, end) 时间范围
  String get chartSql =>
      'SELECT $aggregate($sensorName) FROM $device WHERE time >= $startMs AND time <= $endMs '
      'GROUP BY([$startMs, ${endMs + 1}), $interval)';

  DataQuery copyWith({int? page}) => DataQuery(
    device: device,
    timeseries: timeseries,
    startMs: startMs,
    endMs: endMs,
    interval: interval,
    aggregate: aggregate,
    pageSize: pageSize,
    page: page ?? this.page,
  );
}

/// 数值型测点可用 avg；其余（TEXT/BOOLEAN/BLOB 等）用 count
String aggregateFor(String dataType) {
  const numeric = {'INT32', 'INT64', 'FLOAT', 'DOUBLE'};
  return numeric.contains(dataType) ? 'avg' : 'count';
}

/// 时间范围预设
enum TimeRange { h1, h6, h24, d7, d30 }

extension TimeRangeX on TimeRange {
  String get label => switch (this) {
    TimeRange.h1 => '最近 1 小时',
    TimeRange.h6 => '最近 6 小时',
    TimeRange.h24 => '最近 24 小时',
    TimeRange.d7 => '最近 7 天',
    TimeRange.d30 => '最近 30 天',
  };

  Duration get duration => switch (this) {
    TimeRange.h1 => const Duration(hours: 1),
    TimeRange.h6 => const Duration(hours: 6),
    TimeRange.h24 => const Duration(hours: 24),
    TimeRange.d7 => const Duration(days: 7),
    TimeRange.d30 => const Duration(days: 30),
  };

  /// 默认聚合窗口（保证 ~500 个数据点）
  String get defaultInterval => switch (this) {
    TimeRange.h1 => '10000ms',
    TimeRange.h6 => '1m',
    TimeRange.h24 => '5m',
    TimeRange.d7 => '1h',
    TimeRange.d30 => '1d',
  };
}

/// 可选的聚合窗口（UI 下拉）
const intervalOptions = ['auto', '10s', '1m', '5m', '1h', '1d'];

/// 原始数据（分页）
final rawDataProvider = FutureProvider.family<QueryResult, DataQuery>((ref, q) {
  return ref.watch(iotdbClientProvider).query(q.rawSql);
});

/// 时间窗内总行数（分页 footer 用）
final rawCountProvider = FutureProvider.family<int, DataQuery>((ref, q) async {
  final r = await ref.watch(iotdbClientProvider).query(q.countSql);
  if (r.rows.isEmpty) return 0;
  return int.tryParse('${r.rows.first.first}') ?? 0;
});

/// 聚合数据（折线图）
final chartDataProvider = FutureProvider.family<QueryResult, DataQuery>((
  ref,
  q,
) {
  return ref.watch(iotdbClientProvider).query(q.chartSql);
});
