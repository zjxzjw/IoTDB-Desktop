import '../models/query_result.dart';

/// 元数据节点类型
enum MetaNodeType { database, device, timeseries }

/// 元数据树节点（数据库 / 设备 / 测点）
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
