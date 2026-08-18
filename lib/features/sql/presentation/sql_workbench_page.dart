import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:re_editor/re_editor.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/models/sql_run_result.dart';
import '../../../core/models/table_meta.dart';
import '../../../core/network/statement_router.dart';
import '../../../core/providers.dart';
import '../../../core/theme/shadcn_tokens.dart';
import '../../database/data/database_providers.dart';
import '../data/sql_history_provider.dart';
import '../data/sql_workbench_provider.dart';
import 'result_panel.dart';
import 'sql_autocomplete.dart';
import 'sql_editor.dart';

/// SQL 工作台：SQL 编辑器（上半） + 执行结果（下半，可拖拽调整高度）
class SqlWorkbenchPage extends ConsumerStatefulWidget {
  final String? initialSql;

  const SqlWorkbenchPage({super.key, this.initialSql});

  @override
  ConsumerState<SqlWorkbenchPage> createState() => _SqlWorkbenchPageState();
}

class _SqlWorkbenchPageState extends ConsumerState<SqlWorkbenchPage> {
  static const double _minEditorHeight = 120;
  static const double _minResultsHeight = 120;

  final CodeLineEditingController _controller = CodeLineEditingController();
  final FocusNode _focusNode = FocusNode();

  /// 当前是否有非空选中文本（驱动运行按钮文字：运行/运行选中）
  bool _hasSelection = false;

  String get _connId => ref.read(activeConnectionProvider)?.id ?? '';

  @override
  void initState() {
    super.initState();
    final ws = ref.read(sqlWorkbenchProvider(_connId));
    if (ws.sqlText.isNotEmpty) {
      _controller.text = ws.sqlText;
    } else if (widget.initialSql != null && widget.initialSql!.isNotEmpty) {
      _controller.text = widget.initialSql!;
    }
    _controller.addListener(_onTextChanged);
    _controller.addListener(_onSelectionChanged);
    // 消费表管理页「数据浏览」写入的待执行 SQL：写入编辑器并自动执行。
    // 推迟到首帧完成后再读写 provider，避免在 build 期间修改 provider 触发断言。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final pending = ref.read(pendingSqlRunProvider);
      if (pending != null && pending.isNotEmpty) {
        _controller.text = pending;
        ref.read(pendingSqlRunProvider.notifier).clear();
        _run();
      }
    });
  }

  void _onSelectionChanged() {
    final has = _controller.selectedText.trim().isNotEmpty;
    if (has == _hasSelection) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (has != _hasSelection) setState(() => _hasSelection = has);
    });
  }

  void _onTextChanged() {
    // re_editor 在聚焦/重建时会把 controller 内部表示重写为带前导空行的形式，
    // 捕获时做 trim 归一化，避免把多余的空白行持久化（SQL 对首尾空白不敏感）。
    final text = _controller.text.trim();
    if (ref.read(sqlWorkbenchProvider(_connId)).sqlText == text) return;
    // re_editor 在 initState/build 期间也会触发 controller 通知，
    // 需延迟到帧末再写回 provider，避免在 widget 构建阶段修改状态。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(sqlWorkbenchProvider(_connId).notifier).setSqlText(text);
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.removeListener(_onSelectionChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onResizeDrag(double dy, double total) {
    final maxEditor = (total - _minResultsHeight).clamp(
      _minEditorHeight.toDouble(),
      double.infinity,
    );
    final ratio = ref.read(sqlWorkbenchProvider(_connId)).editorRatio;
    final newHeight = (total * ratio + dy).clamp(
      _minEditorHeight.toDouble(),
      maxEditor,
    );
    ref
        .read(sqlWorkbenchProvider(_connId).notifier)
        .setEditorRatio(newHeight / total);
  }

  /// 按 ; 拆分语句（简单处理：忽略空段与纯注释段）
  List<String> _splitStatements(String sql) {
    return sql
        .split(';')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && !_isCommentOnly(s))
        .toList();
  }

  bool _isCommentOnly(String sql) {
    final text = sql.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '').trim();
    return text.split('\n').every((line) => line.trim().startsWith('--'));
  }

  Future<void> _run() async {
    // 有选中时只执行选中文本，否则执行全部
    final selected = _controller.selectedText.trim();
    final sql = selected.isNotEmpty ? selected : _controller.text.trim();
    if (sql.isEmpty) return;
    final client = ref.read(iotdbClientProvider);
    final conn = ref.read(activeConnectionProvider);

    final statements = _splitStatements(sql);
    ref
        .read(sqlWorkbenchProvider(_connId).notifier)
        .setResults(const [SqlRunResult.running()]);
    final results = <SqlRunResult>[];
    final sw = Stopwatch()..start();
    var success = true;
    for (final stmt in statements) {
      try {
        if (StatementRouter.isQuery(stmt)) {
          final r = await client.query(stmt, rowLimit: conn?.rowLimit);
          results.add(SqlRunResult.success(query: r, sql: stmt, elapsedMs: r.elapsedMs));
        } else {
          final ms = Stopwatch()..start();
          await client.nonQuery(stmt);
          results.add(SqlRunResult.success(message: '执行成功（${ms.elapsedMilliseconds}ms）', sql: stmt, elapsedMs: ms.elapsedMilliseconds));
        }
      } catch (e) {
        success = false;
        results.add(SqlRunResult.error('$e', stmt));
        break;
      }
    }
    ref.read(sqlHistoryProvider.notifier).add(SqlHistoryEntry(
      sql: sql,
      executedAt: DateTime.now(),
      success: success,
      elapsedMs: sw.elapsedMilliseconds,
    ));
    if (!mounted) return;
    ref.read(sqlWorkbenchProvider(_connId).notifier).setResults(results);
    if (_focusNode.hasFocus || _focusNode.canRequestFocus) {
      _focusNode.requestFocus();
    }
  }

  void _showHistory() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) => Dialog(
        backgroundColor: ShadTokens.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ShadTokens.radiusLarge),
        ),
        child: _HistorySheet(controller: _controller),
      ),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeIn,
        );
        return ScaleTransition(
          scale: Tween<double>(begin: 0.85, end: 1.0).animate(curved),
          child: FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
              reverseCurve: Curves.easeIn,
            ),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentDb = ref.watch(databaseSelectionProvider);
    final ws = ref.watch(sqlWorkbenchProvider(_connId));
    final acData = _buildAutocompleteData(currentDb);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTabBar(currentDb),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final total = constraints.maxHeight;
              final maxEditor = (total - _minResultsHeight).clamp(
                _minEditorHeight.toDouble(),
                double.infinity,
              );
              final editorHeight = (total * ws.editorRatio).clamp(
                _minEditorHeight.toDouble(),
                maxEditor,
              );
              return Column(
                children: [
                  SizedBox(
                    height: editorHeight,
                    child: SqlEditor(
                      controller: _controller,
                      focusNode: _focusNode,
                      onRun: _run,
                      autocompleteData: acData,
                    ),
                  ),
                  _SqlSplitHandle(onDrag: (dy) => _onResizeDrag(dy, total)),
                  Expanded(
                    child: ResultPanel(results: ws.results),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  /// 组装补全元数据：当前库的表列表 + 各表列（Riverpod 缓存 DESC 调用）
  SqlAutocompleteData? _buildAutocompleteData(String? currentDb) {
    if (currentDb == null || ref.read(activeConnectionProvider) == null) {
      return null;
    }
    final tableResult = ref.watch(tableListProvider(currentDb));
    final tableQuery = tableResult.value;
    if (tableQuery == null) return null;

    final tables = parseTables(tableQuery, currentDb);
    final names = [for (final m in tables) m.name];
    final columnsByTable = <String, List<TableColumn>>{};
    for (final m in tables) {
      final cols = ref
          .watch(columnListProvider(TableRef(currentDb, m.name)))
          .value;
      if (cols != null) {
        columnsByTable[m.name] = parseColumns(cols);
      }
    }
    return SqlAutocompleteData(
      db: currentDb,
      keywords: SqlKeywords.all,
      tables: names,
      columnsByTable: columnsByTable,
    );
  }

  Widget _buildTabBar(String? currentDb) {
    return Container(
      height: 40,
      decoration: const BoxDecoration(
        color: ShadTokens.card,
        border: Border(bottom: BorderSide(color: ShadTokens.divider)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: ShadTokens.space3),
            decoration: const BoxDecoration(
              border: Border(right: BorderSide(color: ShadTokens.divider)),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 240),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    RemixIcons.database_2_line,
                    size: 15,
                    color: ShadTokens.primary,
                  ),
                  const SizedBox(width: ShadTokens.space2),
                  Flexible(
                    child: Text(
                      currentDb ?? '未选择数据库',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: ShadTokens.fontBody,
                        color: currentDb == null
                            ? ShadTokens.placeholder
                            : ShadTokens.foreground,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(left: ShadTokens.space3),
            child: Text(
              'SQL编辑器',
              style: TextStyle(
                fontSize: ShadTokens.fontBody,
                color: ShadTokens.mutedForeground,
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: '执行历史',
            onPressed: _showHistory,
            icon: const Icon(RemixIcons.history_line, size: 18),
          ),
          const SizedBox(width: ShadTokens.space2),
          FilledButton.icon(
            onPressed: _run,
            icon: const Icon(RemixIcons.arrow_right_s_line, size: 16),
            label: Text(_hasSelection ? '运行选中' : '运行'),
          ),
          const SizedBox(width: ShadTokens.space3),
        ],
      ),
    );
  }
}

/// 编辑器与结果区之间的纵向拖拽手柄：拖拽调整上下分区高度
class _SqlSplitHandle extends StatelessWidget {
  final ValueChanged<double> onDrag;

  const _SqlSplitHandle({required this.onDrag});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeUpDown,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: (d) => onDrag(d.delta.dy),
        onVerticalDragEnd: (_) {},
        child: SizedBox(
          height: 6,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: Container(height: 1, color: ShadTokens.border),
              ),
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ShadTokens.mutedForeground,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 执行历史弹窗（居中 Dialog）：标题 + 圆角分组列表，无标题分割线
class _HistorySheet extends ConsumerWidget {
  final CodeLineEditingController controller;

  const _HistorySheet({required this.controller});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(sqlHistoryProvider);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: SizedBox(
        width: 560,
        height: 460,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 标题区：图标 + 标题 + 清空 + 关闭（与新建库弹窗一致）
            Padding(
              padding: const EdgeInsets.fromLTRB(
                ShadTokens.space6,
                ShadTokens.space4,
                ShadTokens.space4,
                ShadTokens.space2,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(RemixIcons.history_line, size: 18, color: ShadTokens.primary),
                  const SizedBox(width: ShadTokens.space2),
                  const Text(
                    '执行历史',
                    style: TextStyle(fontSize: ShadTokens.fontTitle, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  if (list.isNotEmpty)
                    TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(
                          horizontal: ShadTokens.space3,
                          vertical: ShadTokens.space1,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => ref.read(sqlHistoryProvider.notifier).clear(),
                      child: const Text('清空'),
                    ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: '关闭',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(RemixIcons.close_line, size: 18),
                  ),
                ],
              ),
            ),
            // 列表区
            Expanded(
              child: list.isEmpty
                  ? _HistoryEmpty()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: ShadTokens.space4,
                        vertical: ShadTokens.space1,
                      ),
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        final e = list[list.length - 1 - i]; // 最新的在最上方
                        return _HistoryItem(
                          entry: e,
                          onTap: () {
                            final current = controller.text;
                            // 追加而非覆盖：若已有内容且不以分号结尾，才用分号+换行分隔
                            final trimmed = current.trimRight();
                            controller.text = current.isEmpty
                                ? e.sql
                                : '${trimmed.endsWith(';') ? trimmed : '$trimmed;'}\n${e.sql}';
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 空状态
class _HistoryEmpty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            RemixIcons.history_line,
            size: 36,
            color: scheme.outlineVariant,
          ),
          const SizedBox(height: ShadTokens.space3),
          Text(
            '暂无执行记录',
            style: TextStyle(
              fontSize: ShadTokens.fontBody,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: ShadTokens.space1),
          Text(
            '运行 SQL 后将在此显示历史',
            style: TextStyle(
              fontSize: ShadTokens.fontAux,
              color: scheme.outlineVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// 单条历史：圆形状态徽章 + SQL 摘要 + 相对时间，整体圆角分组
class _HistoryItem extends StatelessWidget {
  final SqlHistoryEntry entry;
  final VoidCallback onTap;

  const _HistoryItem({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ok = entry.success;
    final accent = ok ? ShadTokens.success : ShadTokens.destructive;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(ShadTokens.radiusMedium),
      child: InkWell(
        borderRadius: BorderRadius.circular(ShadTokens.radiusMedium),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: ShadTokens.space3,
            vertical: ShadTokens.space3,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 状态徽章
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  ok ? RemixIcons.check_line : RemixIcons.close_line,
                  size: 16,
                  color: accent,
                ),
              ),
              const SizedBox(width: ShadTokens.space3),
              // SQL 与时间
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.sql.replaceAll(RegExp(r'\s+'), ' ').trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: ShadTokens.fontBody,
                        color: scheme.onSurface,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          _formatRelativeTime(entry.executedAt),
                          style: TextStyle(
                            fontSize: ShadTokens.fontAux,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        if (entry.elapsedMs != null) ...[
                          const SizedBox(width: ShadTokens.space2),
                          Text(
                            '· ${entry.elapsedMs}ms',
                            style: TextStyle(
                              fontSize: ShadTokens.fontAux,
                              color: scheme.outlineVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: ShadTokens.space2),
              Icon(
                RemixIcons.arrow_right_s_line,
                size: 16,
                color: scheme.outlineVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 相对时间格式化（苹果风：刚刚 / N 分钟前 / 今天 HH:mm / MM-DD）
String _formatRelativeTime(DateTime t) {
  final now = DateTime.now();
  final diff = now.difference(t);
  if (diff.inSeconds < 60) return '刚刚';
  if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
  final sameDay = t.year == now.year && t.month == now.month && t.day == now.day;
  if (sameDay) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }
  if (diff.inDays < 7) return '${diff.inDays} 天前';
  return '${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
}