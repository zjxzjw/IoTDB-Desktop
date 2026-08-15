import 'query_result.dart';

enum SqlRunKind { idle, running, success, error }

/// 一次 SQL 执行的结果
class SqlRunResult {
  final SqlRunKind kind;
  final QueryResult? query;
  final String? message;
  final int? elapsedMs;
  final String sql;

  const SqlRunResult.idle()
      : kind = SqlRunKind.idle,
        query = null,
        message = null,
        elapsedMs = null,
        sql = '';

  const SqlRunResult.running()
      : kind = SqlRunKind.running,
        query = null,
        message = null,
        elapsedMs = null,
        sql = '';

  SqlRunResult.success({this.query, this.message, this.elapsedMs, required this.sql})
      : kind = SqlRunKind.success;

  SqlRunResult.error(this.message, this.sql)
      : kind = SqlRunKind.error,
        query = null,
        elapsedMs = null;
}
