import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iotdb_desktop/core/models/query_result.dart';
import 'package:iotdb_desktop/core/models/table_meta.dart';
import 'package:iotdb_desktop/core/network/iotdb_client.dart';
import 'package:iotdb_desktop/core/providers.dart';
import 'package:iotdb_desktop/features/database/data/database_providers.dart';

/// 用假客户端 + 可选固定元数据 override 包装被测组件
///
/// 注：Riverpod 3 未导出 `Override` 类型，故在此处内联构造 overrides。
Widget wrapWithProvider({
  required Widget child,
  required IotdbClient client,
  String? db,
  String? table,
  QueryResult? dbList,
  QueryResult? tables,
  QueryResult? columns,
}) {
  return ProviderScope(
    overrides: [
      iotdbClientProvider.overrideWithValue(client),
      if (db != null)
        databaseSelectionProvider.overrideWith(() => _FixedDbSelection(db)),
      if (table != null)
        tableSelectionProvider.overrideWith(() => _FixedTableSelection(table)),
      if (dbList != null)
        databaseListProvider.overrideWith(() => _FixedDatabaseList(dbList)),
      if (tables != null)
        tableListProvider.overrideWith((ref, arg) => Future.value(tables)),
      if (columns != null)
        columnListProvider.overrideWith((ref, tr) => Future.value(columns)),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

class _FixedDatabaseList extends DatabaseListNotifier {
  final QueryResult result;
  _FixedDatabaseList(this.result);

  @override
  Future<QueryResult> build() async => result;
}

class _FixedDbSelection extends DatabaseSelectionNotifier {
  final String? value;
  _FixedDbSelection(this.value);

  @override
  String? build() => value;
}

class _FixedTableSelection extends TableSelectionNotifier {
  final String? value;
  _FixedTableSelection(this.value);

  @override
  String? build() => value;
}

/// 放大测试画布，避免较高/较宽的表单内容被裁剪无法点击
void enlargeSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// 便捷构造 QueryResult
QueryResult qr({
  List<String> columns = const [],
  List<List<dynamic>> rows = const [],
}) {
  return QueryResult(
    columnNames: columns,
    rows: rows,
    dataTypes: const [],
    elapsedMs: 0,
  );
}

/// 便捷构造 TableColumn
TableColumn col(
  String name,
  String type,
  ColumnCategory category, {
  String? comment,
}) {
  return TableColumn(
    name: name,
    dataType: type,
    category: category,
    comment: comment,
  );
}
