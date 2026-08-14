import 'package:flutter_riverpod/flutter_riverpod.dart';

/// SQL 历史条目（会话内存）
class SqlHistoryEntry {
  final String sql;
  final DateTime executedAt;
  final bool success;
  final int? elapsedMs;

  const SqlHistoryEntry({
    required this.sql,
    required this.executedAt,
    required this.success,
    this.elapsedMs,
  });
}

/// SQL 执行历史（会话内，上限 100 条）
final sqlHistoryProvider = NotifierProvider<SqlHistoryNotifier, List<SqlHistoryEntry>>(
  SqlHistoryNotifier.new,
);

class SqlHistoryNotifier extends Notifier<List<SqlHistoryEntry>> {
  static const _maxEntries = 100;

  @override
  List<SqlHistoryEntry> build() => [];

  void add(SqlHistoryEntry entry) {
    state = [...state, entry].takeLast(_maxEntries).toList();
  }

  void clear() => state = [];
}

extension _TakeLast on List<SqlHistoryEntry> {
  List<SqlHistoryEntry> takeLast(int n) =>
      length <= n ? this : sublist(length - n);
}
