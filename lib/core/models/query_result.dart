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

  /// 解析 REST 响应。
  ///
  /// 两种格式：
  /// 1. 表模型端点 `/rest/table/v1/query`（本工具当前使用）：
  ///    { column_names, values(行主序), data_types }，无 timestamps，time 为普通列。
  /// 2. 树模型端点 `/rest/v2/query`（兼容保留）：
  ///    { expressions|column_names, values(列主序), timestamps, data_types }。
  factory QueryResult.fromRestJson(Map<String, dynamic> json, int elapsedMs) {
    final columnNames =
        (json['column_names'] as List<dynamic>? ??
                json['columns'] as List<dynamic>? ??
                json['expressions'] as List<dynamic>? ??
                [])
            .map((e) => e.toString())
            .toList();
    final timestamps = json['timestamps'] as List<dynamic>?;
    final values =
        json['values'] as List<dynamic>? ??
        json['rows'] as List<dynamic>? ??
        [];
    final dataTypes = (json['data_types'] as List<dynamic>?)
        ?.map((e) => e?.toString())
        .toList();

    // 树模型 v2 风格：values 列主序，timestamps 补为 Time 列
    if (timestamps != null) {
      final names = [...columnNames];
      if (!names.contains('Time')) names.insert(0, 'Time');
      final rows = <List<dynamic>>[];
      for (var i = 0; i < timestamps.length; i++) {
        final row = <dynamic>[timestamps[i]];
        for (final col in values) {
          final colList = col as List<dynamic>;
          row.add(i < colList.length ? colList[i] : null);
        }
        rows.add(row);
      }
      return QueryResult(
        columnNames: names,
        rows: rows,
        dataTypes: dataTypes ?? const [],
        elapsedMs: elapsedMs,
      );
    }

    // 表模型：values 行主序，每行即一个数据行
    final rows = <List<dynamic>>[
      for (final v in values)
        if (v is List) v else <dynamic>[v],
    ];
    return QueryResult(
      columnNames: columnNames,
      rows: rows,
      dataTypes: dataTypes ?? const [],
      elapsedMs: elapsedMs,
    );
  }
}
