import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/models/query_result.dart';
import '../../../core/theme/tdesign_tokens.dart';
import '../../../shared/empty_state.dart';
import '../../../shared/result_table.dart';

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

/// 结果面板：渲染 SQL 执行结果列表（多语句时逐条展示）
class ResultPanel extends StatelessWidget {
  final List<SqlRunResult> results;

  const ResultPanel({super.key, required this.results});

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return const EmptyState(
        icon: RemixIcons.play_circle_line,
        title: '执行 SQL 以查看结果',
        description: 'Cmd/Ctrl + Enter 快速执行',
      );
    }
    final anyRunning = results.any((r) => r.kind == SqlRunKind.running);
    if (anyRunning) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    final errorCount = results.where((r) => r.kind == SqlRunKind.error).length;
    return Column(
      children: [
        if (results.length > 1)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: TdTokens.space4, vertical: 6),
            color: TdTokens.bgPage,
            child: Text(
              '共 ${results.length} 条语句，失败 $errorCount 条',
              style: TextStyle(
                fontSize: TdTokens.fontAux,
                color: errorCount > 0 ? TdTokens.danger : TdTokens.textSecondary,
              ),
            ),
          ),
        Expanded(
          child: ListView(
            children: [for (final r in results) _ResultItem(result: r)],
          ),
        ),
      ],
    );
  }
}

class _ResultItem extends StatelessWidget {
  final SqlRunResult result;

  const _ResultItem({required this.result});

  @override
  Widget build(BuildContext context) {
    switch (result.kind) {
      case SqlRunKind.error:
        return Container(
          margin: const EdgeInsets.all(TdTokens.space4),
          padding: const EdgeInsets.all(TdTokens.space3),
          decoration: BoxDecoration(
            color: TdTokens.danger.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(TdTokens.radiusDefault),
            border: Border.all(color: TdTokens.danger.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(RemixIcons.error_warning_line, size: 16, color: TdTokens.danger),
                  SizedBox(width: TdTokens.space2),
                  Text(
                    '执行失败',
                    style: TextStyle(fontSize: TdTokens.fontBody, fontWeight: FontWeight.w600, color: TdTokens.danger),
                  ),
                ],
              ),
              const SizedBox(height: TdTokens.space2),
              Text('${result.message}', style: const TextStyle(fontSize: TdTokens.fontBody)),
            ],
          ),
        );
      case SqlRunKind.success:
        final q = result.query;
        if (q != null) {
          return SizedBox(
            height: 320,
            child: ResultTable(columns: q.columnNames, rows: q.rows, elapsedMs: q.elapsedMs),
          );
        }
        return Container(
          margin: const EdgeInsets.all(TdTokens.space4),
          padding: const EdgeInsets.all(TdTokens.space3),
          decoration: BoxDecoration(
            color: TdTokens.success.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(TdTokens.radiusDefault),
            border: Border.all(color: TdTokens.success.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              const Icon(RemixIcons.check_line, size: 16, color: TdTokens.success),
              const SizedBox(width: TdTokens.space2),
              Text(
                result.message ?? '执行成功${result.elapsedMs != null ? '（${result.elapsedMs}ms）' : ''}',
                style: const TextStyle(fontSize: TdTokens.fontBody),
              ),
            ],
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}