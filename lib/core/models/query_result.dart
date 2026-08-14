class QueryResult {
  final List<String> columnNames;
  final List<List<dynamic>> rows;
  final List<String?> dataTypes;
  final int elapsedMs;

  const QueryResult({
    required this.columnNames,
    required this.rows,
    required this.dataTypes,
    required this.elapsedMs,
  });

  int get rowCount => rows.length;
  int get columnCount => columnNames.length;

  /// 解析 REST v2 响应（2.0.10 实测格式）：
  /// { column_names[], values[列主序], timestamps?, data_types? }
  /// 注：SELECT 类查询返回 `expressions` 而非 `column_names`，需兜底
  factory QueryResult.fromRestJson(Map<String, dynamic> json, int elapsedMs) {
    final columnNames = (json['column_names'] as List<dynamic>? ?? json['columns'] as List<dynamic>? ?? json['expressions'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();
    final timestamps = json['timestamps'] as List<dynamic>?;
    final values = json['values'] as List<dynamic>? ?? json['rows'] as List<dynamic>? ?? [];
    final dataTypes = (json['data_types'] as List<dynamic>?)
        ?.map((e) => e?.toString())
        .toList();

    final rowCount = timestamps != null ? timestamps.length : (values.isNotEmpty ? (values.first as List).length : 0);
    final names = [...columnNames];
    if (timestamps != null && !names.contains('Time')) names.insert(0, 'Time');

    final rows = <List<dynamic>>[];
    for (var i = 0; i < rowCount; i++) {
      final row = <dynamic>[];
      if (timestamps != null) row.add(timestamps[i]);
      for (final col in values) {
        final colList = col as List<dynamic>;
        row.add(i < colList.length ? colList[i] : null);
      }
      rows.add(row);
    }
    return QueryResult(columnNames: names, rows: rows, dataTypes: dataTypes ?? const [], elapsedMs: elapsedMs);
  }
}
