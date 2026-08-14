/// SQL 语句路由：判定走 /rest/v2/query 还是 /rest/v2/nonQuery
///
/// 启发式（2.0.10 实测）：数据/元数据查询关键字 → query，其余（DDL/DML/权限）→ nonQuery
class StatementRouter {
  static const List<String> _queryPrefixes = [
    'SELECT',
    'SHOW',
    'COUNT',
    'LIST',
    'DESCRIBE',
    'DESC',
    'EXPLAIN',
    'LOAD',
  ];

  /// 取首词，忽略前导注释（-- 、/* */）与空白
  static String _firstKeyword(String sql) {
    final text = sql.trimLeft();
    if (text.startsWith('--')) {
      final lineEnd = text.indexOf('\n');
      return _firstKeyword(lineEnd < 0 ? '' : text.substring(lineEnd + 1));
    }
    if (text.startsWith('/*')) {
      final blockEnd = text.indexOf('*/');
      return _firstKeyword(blockEnd < 0 ? '' : text.substring(blockEnd + 2));
    }
    final match = RegExp(r'^[A-Za-z]+').firstMatch(text);
    return match?.group(0)?.toUpperCase() ?? '';
  }

  /// true → query 接口；false → nonQuery 接口
  static bool isQuery(String sql) {
    final keyword = _firstKeyword(sql);
    if (keyword.isEmpty) return false;
    return _queryPrefixes.any((p) => keyword.startsWith(p));
  }
}
