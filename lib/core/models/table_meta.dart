import 'query_result.dart';

/// 列类别（表模型四类列）
enum ColumnCategory { time, tag, attribute, field }

extension ColumnCategoryX on ColumnCategory {
  String get label => switch (this) {
    ColumnCategory.time => '时间列',
    ColumnCategory.tag => '标签列',
    ColumnCategory.attribute => '属性列',
    ColumnCategory.field => '测点列',
  };

  String get sqlKeyword => switch (this) {
    ColumnCategory.time => 'TIME',
    ColumnCategory.tag => 'TAG',
    ColumnCategory.attribute => 'ATTRIBUTE',
    ColumnCategory.field => 'FIELD',
  };
}

/// 表模型可选数据类型
const tableDataTypes = [
  'BOOLEAN',
  'INT32',
  'INT64',
  'FLOAT',
  'DOUBLE',
  'STRING',
  'DATE',
  'TIMESTAMP',
  'BLOB',
];

/// 数值类型（图表可用 avg）
bool isNumericType(String type) {
  const numeric = {'INT32', 'INT64', 'FLOAT', 'DOUBLE'};
  return numeric.contains(type.toUpperCase());
}

/// 一列定义（来自 DESC `<db>.<table>`）
class TableColumn {
  final String name;
  final String dataType;
  final ColumnCategory category;
  final String? comment;
  final String? status;

  const TableColumn({
    required this.name,
    required this.dataType,
    required this.category,
    this.comment,
    this.status,
  });

  bool get canDrop => category == ColumnCategory.field || category == ColumnCategory.attribute;
}

/// 一张表（来自 SHOW TABLES DETAILS FROM `<db>`）
class TableMeta {
  final String db;
  final String name;
  final String? ttl;
  final String? status;
  final String? comment;
  final List<TableColumn> columns;

  const TableMeta({
    required this.db,
    required this.name,
    this.ttl,
    this.status,
    this.comment,
    this.columns = const [],
  });
}

/// 库表引用（作为 provider family 的键）
class TableRef {
  final String db;
  final String table;

  const TableRef(this.db, this.table);

  @override
  bool operator ==(Object other) =>
      other is TableRef && other.db == db && other.table == table;

  @override
  int get hashCode => Object.hash(db, table);

  @override
  String toString() => '$db.$table';
}

ColumnCategory _categoryOf(String value) {
  switch (value.toUpperCase()) {
    case 'TIME':
      return ColumnCategory.time;
    case 'TAG':
      return ColumnCategory.tag;
    case 'ATTRIBUTE':
      return ColumnCategory.attribute;
    default:
      return ColumnCategory.field;
  }
}

int _columnIndex(QueryResult r, String name) {
  for (var i = 0; i < r.columnNames.length; i++) {
    final lower = r.columnNames[i].toLowerCase();
    // 兼容服务器返回的 `TTL(ms)` 这类带单位列名
    if (lower == name || lower.startsWith('$name(')) return i;
  }
  return -1;
}

dynamic _cell(QueryResult r, List<dynamic> row, int col) =>
    col >= 0 && col < row.length ? row[col] : null;

/// 解析 SHOW TABLES DETAILS 结果
List<TableMeta> parseTables(QueryResult r, String db) {
  final iName = _columnIndex(r, 'tablename');
  final iTtl = _columnIndex(r, 'ttl');
  final iStatus = _columnIndex(r, 'status');
  final iComment = _columnIndex(r, 'comment');
  return [
    for (final row in r.rows)
      TableMeta(
        db: db,
        name: (_cell(r, row, iName) ?? row.first).toString(),
        ttl: _cell(r, row, iTtl)?.toString(),
        status: _cell(r, row, iStatus)?.toString(),
        comment: _cell(r, row, iComment)?.toString(),
      ),
  ];
}

/// 解析 DESC `<db>.<table>` 结果
List<TableColumn> parseColumns(QueryResult r) {
  final iName = _columnIndex(r, 'columnname');
  final iType = _columnIndex(r, 'datatype');
  final iCat = _columnIndex(r, 'category');
  final iStatus = _columnIndex(r, 'status');
  final iComment = _columnIndex(r, 'comment');
  return [
    for (final row in r.rows)
      TableColumn(
        name: (_cell(r, row, iName) ?? row.first).toString(),
        dataType: _cell(r, row, iType)?.toString() ?? '',
        category: _categoryOf(_cell(r, row, iCat)?.toString() ?? ''),
        status: _cell(r, row, iStatus)?.toString(),
        comment: _cell(r, row, iComment)?.toString(),
      ),
  ];
}
