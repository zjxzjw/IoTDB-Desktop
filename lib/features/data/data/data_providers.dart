import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/query_result.dart';
import '../../../core/providers.dart';
import '../../../core/utils/sql_builder.dart';

/// 表模型数据查询参数（family 键：任一字段变化自动重建查询）
class TableQuery {
  final String db;
  final String table;

  /// 选中展示/聚合的列（不含 time，time 自动补在最前）
  final List<String> columns;

  /// 每列图表聚合方式（avg / count）
  final Map<String, String> columnAggs;

  /// TAG 过滤条件：列名 → 值（等值匹配）
  final Map<String, String> tagFilters;

  final int startMs;
  final int endMs;
  final String interval; // 聚合窗口，如 5m / 1h
  final int page;
  final int pageSize;

  const TableQuery({
    required this.db,
    required this.table,
    required this.columns,
    required this.columnAggs,
    this.tagFilters = const {},
    required this.startMs,
    required this.endMs,
    required this.interval,
    this.page = 0,
    this.pageSize = 100,
  });

  String get _qualified => SqlBuilder.qualified(db, table);

  List<String> get _selectList {
    final list = ['time', ...columns];
    final seen = <String>{};
    return [
      for (final c in list)
        if (seen.add(c.toLowerCase())) c,
    ];
  }

  /// 原始表展示列（time 在前）
  List<String> get displayColumns => _selectList;

  String _whereClause() {
    final conds = <String>[
      'time >= $startMs AND time <= $endMs',
      for (final e in tagFilters.entries)
        if (e.value.trim().isNotEmpty)
          "${SqlBuilder.ident(e.key)} = '${_escape(e.value.trim())}'",
    ];
    return conds.join(' AND ');
  }

  /// SELECT 原始数据（服务端分页）
  String get rawSql {
    final cols = _selectList.map(SqlBuilder.ident).join(', ');
    return 'SELECT $cols FROM $_qualified WHERE ${_whereClause()} '
        'LIMIT $pageSize OFFSET ${page * pageSize}';
  }

  /// 时间窗内总行数
  String get countSql =>
      'SELECT count(*) FROM $_qualified WHERE ${_whereClause()}';

  /// 聚合查询（图表降采样）：表模型用 date_bin_gapfill + GROUP BY 1
  String get chartSql {
    final aggs = columns
        .map((c) =>
            '${columnAggs[c] ?? 'avg'}(${SqlBuilder.ident(c)}) AS ${SqlBuilder.ident(c)}')
        .join(', ');
    return 'SELECT date_bin_gapfill($interval, time) AS time, $aggs '
        'FROM $_qualified WHERE ${_whereClause()} '
        'GROUP BY 1 FILL METHOD PREVIOUS';
  }

  TableQuery copyWith({int? page}) => TableQuery(
    db: db,
    table: table,
    columns: columns,
    columnAggs: columnAggs,
    tagFilters: tagFilters,
    startMs: startMs,
    endMs: endMs,
    interval: interval,
    pageSize: pageSize,
    page: page ?? this.page,
  );

  static String _escape(String v) => v.replaceAll("'", "''");
}

/// 数值类型用 avg，其余（STRING/BOOLEAN/…）用 count
String aggregateFor(String dataType) {
  const numeric = {'INT32', 'INT64', 'FLOAT', 'DOUBLE'};
  return numeric.contains(dataType.toUpperCase()) ? 'avg' : 'count';
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
final rawDataProvider = FutureProvider.family<QueryResult, TableQuery>((ref, q) {
  return ref.watch(iotdbClientProvider).query(q.rawSql);
});

/// 时间窗内总行数（分页 footer 用）
final rawCountProvider = FutureProvider.family<int, TableQuery>((ref, q) async {
  final r = await ref.watch(iotdbClientProvider).query(q.countSql);
  if (r.rows.isEmpty) return 0;
  return int.tryParse('${r.rows.first.first}') ?? 0;
});

/// 聚合数据（折线图）
final chartDataProvider =
    FutureProvider.family<QueryResult, TableQuery>((ref, q) {
      return ref.watch(iotdbClientProvider).query(q.chartSql);
    });
