import 'package:iotdb_desktop/core/models/connection.dart';
import 'package:iotdb_desktop/core/models/query_result.dart';
import 'package:iotdb_desktop/core/network/iotdb_client.dart';

import 'test_connection.dart';

/// 记录调用、可注入返回/异常的假客户端（不发起真实网络请求）
class FakeIotdbClient extends IotdbClient {
  final List<String> querySql = [];
  final List<String> nonQuerySql = [];

  /// sql → REST 响应 JSON（QueryResult.fromRestJson 的输入）
  final Map<String, Map<String, dynamic>> queryResponses;

  /// sql → 抛错
  final Map<String, Object> queryErrors;
  final Map<String, Object> nonQueryErrors;

  FakeIotdbClient({
    Connection? connection,
    this.queryResponses = const {},
    this.queryErrors = const {},
    this.nonQueryErrors = const {},
  }) : super(connection ?? testConnection());

  @override
  Future<QueryResult> query(String sql, {int? rowLimit}) async {
    querySql.add(sql);
    final err = queryErrors[sql];
    if (err != null) throw err;
    final json = queryResponses[sql] ??
        const {'column_names': [], 'values': [], 'data_types': []};
    return QueryResult.fromRestJson(json, 0);
  }

  @override
  Future<Map<String, dynamic>> nonQuery(String sql) async {
    nonQuerySql.add(sql);
    final err = nonQueryErrors[sql];
    if (err != null) throw err;
    return const {'code': 200, 'message': 'SUCCESS_STATUS'};
  }
}
