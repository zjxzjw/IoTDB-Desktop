import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/models/sql_run_result.dart';
import '../../../core/theme/shadcn_tokens.dart';
import '../../../shared/empty_state.dart';
import '../../../shared/result_table.dart';

/// 结果面板：单语句直接展示，多语句时以标签页（结果1 / 结果2 …）切换
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

    // 单条结果：直接展示，无需标签页
    if (results.length == 1) {
      return _ResultItem(result: results.first, fill: true);
    }

    return _MultiResultTabs(results: results);
  }
}

/// 多语句结果：苹果风分段标签（药丸高亮、左对齐）+ 内容切换
class _MultiResultTabs extends StatefulWidget {
  final List<SqlRunResult> results;

  const _MultiResultTabs({required this.results});

  @override
  State<_MultiResultTabs> createState() => _MultiResultTabsState();
}

class _MultiResultTabsState extends State<_MultiResultTabs>
    with SingleTickerProviderStateMixin {
  late final TabController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TabController(length: widget.results.length, vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final errorCount = widget.results.where((r) => r.kind == SqlRunKind.error).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 标签栏：左对齐分段控件 + 右侧概览（整条底部细分割线）
        Container(
          decoration: BoxDecoration(
            color: ShadTokens.muted,
            border: Border(
              bottom: BorderSide(color: ShadTokens.border, width: 1),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 左对齐：直接贴边，无额外内边距
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: ShadTokens.space3,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      for (var i = 0; i < widget.results.length; i++)
                        _SegmentTab(
                          index: i,
                          result: widget.results[i],
                          controller: _controller,
                        ),
                      const SizedBox(width: ShadTokens.space2),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: ShadTokens.space3),
                child: Text(
                  '共 ${widget.results.length} 条，失败 $errorCount 条',
                  style: TextStyle(
                    fontSize: ShadTokens.fontAux,
                    color: errorCount > 0 ? ShadTokens.destructive : ShadTokens.mutedForeground,
                  ),
                ),
              ),
            ],
          ),
        ),
        // 内容
        Expanded(
          child: TabBarView(
            controller: _controller,
            children: [
              for (final r in widget.results) _ResultItem(result: r, fill: true),
            ],
          ),
        ),
      ],
    );
  }
}

/// 单个苹果风分段标签：选中为圆角药丸（浮起），未选中为次要文字
class _SegmentTab extends StatelessWidget {
  final int index;
  final SqlRunResult result;
  final TabController controller;

  const _SegmentTab({
    required this.index,
    required this.result,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isError = result.kind == SqlRunKind.error;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final selected = controller.index == index;
        return Padding(
          padding: const EdgeInsets.only(right: 4),
          child: InkWell(
            borderRadius: BorderRadius.circular(ShadTokens.radiusDefault),
            onTap: () => controller.animateTo(index),
            child: Container(
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: ShadTokens.space3),
              decoration: selected
                  ? BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(ShadTokens.radiusDefault),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.14),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    )
                  : null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '结果${index + 1}',
                    style: TextStyle(
                      fontSize: ShadTokens.fontBody,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected
                          ? scheme.onSurface
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                  if (isError) ...[
                    const SizedBox(width: 6),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: ShadTokens.destructive,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
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
        return SingleChildScrollView(
          padding: const EdgeInsets.all(ShadTokens.space4),
          child: Container(
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
        return SingleChildScrollView(
          padding: const EdgeInsets.all(ShadTokens.space4),
          child: Container(
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
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
