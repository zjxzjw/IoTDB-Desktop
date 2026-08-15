import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/sql_run_result.dart';

/// 当前 SQL 工作台活动标签的执行结果（供底部「执行结果」面板展示）
final sqlRunResultsProvider = NotifierProvider<SqlRunResultsNotifier, List<SqlRunResult>>(
  SqlRunResultsNotifier.new,
);

class SqlRunResultsNotifier extends Notifier<List<SqlRunResult>> {
  @override
  List<SqlRunResult> build() => const [];

  void set(List<SqlRunResult> results) => state = results;
}
