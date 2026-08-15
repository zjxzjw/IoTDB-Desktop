import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/models/sql_run_result.dart';
import '../../../core/theme/shadcn_tokens.dart';
import '../../../shared/empty_state.dart';
import '../../../shared/result_table.dart';

/// 结果面板：渲染 SQL 执行结果列表（多语句时逐条展示）
class ResultPanel extends StatelessWidget {
  final List<SqlRunResult> results;

  const ResultPanel({super.key, required this.results});

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return const EmptyState(
        title: '执行 SQL 以查看结果',
        description: 'Cmd/Ctrl + Enter 快速执行',
      );
    }
    final anyRunning = results.any((r) => r.kind == SqlRunKind.running);
    if (anyRunning) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    final errorCount = results.where((r) => r.kind == SqlRunKind.error).length;
    final singleQuery = results.length == 1 ? results.first.query : null;
    return Column(
      children: [
        if (results.length > 1)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: ShadTokens.space4, vertical: 6),
            color: ShadTokens.muted,
            child: Text(
              '共 ${results.length} 条语句，失败 $errorCount 条',
              style: TextStyle(
                fontSize: ShadTokens.fontAux,
                color: errorCount > 0 ? ShadTokens.destructive : ShadTokens.mutedForeground,
              ),
            ),
          ),
        Expanded(
          child: singleQuery != null
              ? _ResultItem(result: results.first, fill: true)
              : ListView(
                  children: [for (final r in results) _ResultItem(result: r)],
                ),
        ),
      ],
    );
  }
}

class _ResultItem extends StatelessWidget {
  final SqlRunResult result;
  final bool fill;

  const _ResultItem({required this.result, this.fill = false});

  @override
  Widget build(BuildContext context) {
    switch (result.kind) {
      case SqlRunKind.error:
        return Container(
          margin: const EdgeInsets.all(ShadTokens.space4),
          padding: const EdgeInsets.all(ShadTokens.space3),
          decoration: BoxDecoration(
            color: ShadTokens.destructive.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(ShadTokens.radiusDefault),
            border: Border.all(color: ShadTokens.destructive.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(RemixIcons.error_warning_line, size: 16, color: ShadTokens.destructive),
                  SizedBox(width: ShadTokens.space2),
                  Text(
                    '执行失败',
                    style: TextStyle(fontSize: ShadTokens.fontBody, fontWeight: FontWeight.w600, color: ShadTokens.destructive),
                  ),
                ],
              ),
              const SizedBox(height: ShadTokens.space2),
              Text('${result.message}', style: const TextStyle(fontSize: ShadTokens.fontBody)),
            ],
          ),
        );
      case SqlRunKind.success:
        final q = result.query;
        if (q != null) {
          final table = ResultTable(
            columns: q.columnNames,
            rows: q.rows,
            elapsedMs: q.elapsedMs,
          );
          return fill
              ? table
              : SizedBox(height: 320, child: table);
        }
        return Container(
          margin: const EdgeInsets.all(ShadTokens.space4),
          padding: const EdgeInsets.all(ShadTokens.space3),
          decoration: BoxDecoration(
            color: ShadTokens.success.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(ShadTokens.radiusDefault),
            border: Border.all(color: ShadTokens.success.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              const Icon(RemixIcons.check_line, size: 16, color: ShadTokens.success),
              const SizedBox(width: ShadTokens.space2),
              Text(
                result.message ?? '执行成功${result.elapsedMs != null ? '（${result.elapsedMs}ms）' : ''}',
                style: const TextStyle(fontSize: ShadTokens.fontBody),
              ),
            ],
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}