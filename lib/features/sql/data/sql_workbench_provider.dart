import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/sql_run_result.dart';

/// SQL 工作台会话状态：编辑器内容 / 执行结果 / 分割比例。
/// 以连接 id 为 key 隔离，页面切换时保留，切换连接时为新会话。
class SqlWorkbenchState {
  final String sqlText;
  final List<SqlRunResult> results;
  final double editorRatio;

  const SqlWorkbenchState({
    this.sqlText = '',
    this.results = const [],
    this.editorRatio = 0.45,
  });

  SqlWorkbenchState copyWith({
    String? sqlText,
    List<SqlRunResult>? results,
    double? editorRatio,
  }) {
    return SqlWorkbenchState(
      sqlText: sqlText ?? this.sqlText,
      results: results ?? this.results,
      editorRatio: editorRatio ?? this.editorRatio,
    );
  }
}

/// 每个连接独立的 SQL 工作台会话（会话内常驻，不加 autoDispose 以免页面卸载时被回收）
final sqlWorkbenchProvider =
    NotifierProvider.family<SqlWorkbenchNotifier, SqlWorkbenchState, String>(
      (String _) => SqlWorkbenchNotifier(),
    );

class SqlWorkbenchNotifier extends Notifier<SqlWorkbenchState> {
  @override
  SqlWorkbenchState build() => const SqlWorkbenchState();

  void setSqlText(String text) => state = state.copyWith(sqlText: text);

  void setResults(List<SqlRunResult> results) =>
      state = state.copyWith(results: results);

  void setEditorRatio(double ratio) => state = state.copyWith(editorRatio: ratio);

  void clear() => state = const SqlWorkbenchState();
}
