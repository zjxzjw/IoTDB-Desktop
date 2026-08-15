import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/connection.dart';
import '../../../core/models/query_result.dart';
import '../../../core/models/table_meta.dart';
import '../../../core/network/iotdb_client.dart';
import '../../../core/providers.dart';
import '../../../core/utils/sql_builder.dart';

/// 表列表：SHOW TABLES DETAILS FROM `<db>`（当前活动连接）
final tableListProvider = FutureProvider.family<QueryResult, String>((ref, db) {
  return ref
      .watch(iotdbClientProvider)
      .query('SHOW TABLES DETAILS FROM ${SqlBuilder.ident(db)}');
});

/// 每连接独立的表列表（侧栏多连接同时展开用）
class TableScope {
  final Connection conn;
  final String db;

  const TableScope(this.conn, this.db);

  @override
  bool operator ==(Object other) =>
      other is TableScope && other.conn.id == conn.id && other.db == db;

  @override
  int get hashCode => Object.hash(conn.id, db);
}

final connectionTableListProvider =
    FutureProvider.family<QueryResult, TableScope>((ref, scope) {
      return IotdbClient(scope.conn).query(
        'SHOW TABLES DETAILS FROM ${SqlBuilder.ident(scope.db)}',
      );
    });

/// 列列表：DESC `<db>.<table>` DETAILS（当前活动连接）
final columnListProvider = FutureProvider.family<QueryResult, TableRef>(
  (ref, tableRef) {
    return ref
        .watch(iotdbClientProvider)
        .query('DESC ${SqlBuilder.qualified(tableRef.db, tableRef.table)} DETAILS');
  },
);
