import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:re_editor/re_editor.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/models/sql_run_result.dart';
import '../../../core/network/statement_router.dart';
import '../../../core/providers.dart';
import '../../../core/theme/shadcn_tokens.dart';
import '../data/sql_history_provider.dart';
import '../data/sql_run_results_provider.dart';
import 'sql_editor.dart';

/// SQL 工作台：多标签编辑器 + 历史（执行结果在底部「执行结果」面板）
class SqlWorkbenchPage extends ConsumerStatefulWidget {
  final String? initialSql;
  final VoidCallback? onExecuted;

  const SqlWorkbenchPage({super.key, this.initialSql, this.onExecuted});

  @override
  ConsumerState<SqlWorkbenchPage> createState() => _SqlWorkbenchPageState();
}

class _SqlTab {
  final String title;
  final CodeLineEditingController controller;
  final FocusNode focusNode;
  List<SqlRunResult> results = [];

  _SqlTab(this.title)
      : controller = CodeLineEditingController(),
        focusNode = FocusNode();

  void dispose() {
    controller.dispose();
    focusNode.dispose();
  }
}

class _SqlWorkbenchPageState extends ConsumerState<SqlWorkbenchPage> {
  final List<_SqlTab> _tabs = [];
  int _active = -1;

  _SqlTab? get _current => _active >= 0 && _active < _tabs.length ? _tabs[_active] : null;

  @override
  void initState() {
    super.initState();
    _tabs.add(_SqlTab('查询 1'));
    _active = 0;
    if (widget.initialSql != null && widget.initialSql!.isNotEmpty) {
      _tabs.last.controller.text = widget.initialSql!;
    }
  }

  @override
  void dispose() {
    for (final t in _tabs) {
      t.dispose();
    }
    super.dispose();
  }

  void _addTab() {
    setState(() {
      _tabs.add(_SqlTab('查询 ${_tabs.length + 1}'));
      _active = _tabs.length - 1;
    });
    _syncResults();
  }

  void _closeTab(int index) {
    if (_tabs.length == 1) return;
    final tab = _tabs.removeAt(index);
    tab.dispose();
    if (_active >= _tabs.length) _active = _tabs.length - 1;
    if (index < _active) _active--;
    setState(() {});
    _syncResults();
  }

  /// 将当前活动标签的结果同步到「执行结果」面板
  void _syncResults() {
    final tab = _current;
    ref.read(sqlRunResultsProvider.notifier).set(tab?.results ?? const []);
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
    final tab = _current;
    if (tab == null) return;
    final sql = tab.controller.text.trim();
    if (sql.isEmpty) return;
    final client = ref.read(iotdbClientProvider);
    final conn = ref.read(activeConnectionProvider);

    final statements = _splitStatements(sql);
    setState(() => tab.results = [const SqlRunResult.running()]);
    _syncResults();
    widget.onExecuted?.call();
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
    setState(() => tab.results = results);
    _syncResults();
    if (tab.focusNode.hasFocus || tab.focusNode.canRequestFocus) {
      tab.focusNode.requestFocus();
    }
  }

  void _showHistory() {
    showModalBottomSheet(
      context: context,
      backgroundColor: ShadTokens.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(ShadTokens.radiusLarge)),
      ),
      builder: (ctx) => Consumer(
        builder: (context, ref, _) {
          final list = ref.watch(sqlHistoryProvider);
          return SizedBox(
            height: 420,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(ShadTokens.space4, ShadTokens.space3, ShadTokens.space2, 0),
                  child: Row(
                    children: [
                      const Icon(RemixIcons.history_line, size: 18, color: ShadTokens.primary),
                      const SizedBox(width: ShadTokens.space2),
                      const Text('执行历史', style: TextStyle(fontSize: ShadTokens.fontTitle, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      TextButton(
                        onPressed: () => ref.read(sqlHistoryProvider.notifier).clear(),
                        child: const Text('清空'),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(RemixIcons.close_line, size: 18),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: list.isEmpty
                      ? const Center(
                          child: Text('暂无历史', style: TextStyle(color: ShadTokens.placeholder)),
                        )
                      : ListView.separated(
                          itemCount: list.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final e = list[i];
                            return ListTile(
                              dense: true,
                              leading: Icon(
                                e.success ? RemixIcons.check_line : RemixIcons.close_line,
                                size: 16,
                                color: e.success ? ShadTokens.success : ShadTokens.destructive,
                              ),
                              title: Text(
                                e.sql,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13),
                              ),
                              trailing: Text(
                                e.elapsedMs != null ? '${e.elapsedMs}ms' : '',
                                style: const TextStyle(fontSize: 11, color: ShadTokens.placeholder),
                              ),
                              onTap: () {
                                final tab = _current;
                                if (tab != null) {
                                  tab.controller.text = e.sql;
                                }
                                Navigator.pop(ctx);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentDb = ref.watch(databaseSelectionProvider);
    final current = _current;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTabBar(currentDb),
        Expanded(
          child: current == null
              ? const SizedBox.shrink()
              : SqlEditor(
                  controller: current.controller,
                  focusNode: current.focusNode,
                  onRun: _run,
                ),
        ),
      ],
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
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (var i = 0; i < _tabs.length; i++)
                  _buildTabItem(i),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: '新建查询',
            onPressed: _addTab,
            icon: const Icon(RemixIcons.add_line, size: 18, color: ShadTokens.primary),
          ),
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
            label: const Text('运行'),
          ),
          const SizedBox(width: ShadTokens.space3),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index) {
    final tab = _tabs[index];
    final selected = index == _active;
    return InkWell(
      onTap: () {
        setState(() => _active = index);
        _syncResults();
      },
      child: Container(
        padding: const EdgeInsets.only(left: ShadTokens.space3),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: selected ? Theme.of(context).colorScheme.primary : Colors.transparent, width: 2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tab.title,
              style: TextStyle(
                fontSize: ShadTokens.fontBody,
                color: selected ? Theme.of(context).colorScheme.primary : ShadTokens.mutedForeground,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            if (_tabs.length > 1)
              IconButton(
                visualDensity: VisualDensity.compact,
                iconSize: 14,
                onPressed: () => _closeTab(index),
                icon: const Icon(RemixIcons.close_line),
              ),
          ],
        ),
      ),
    );
  }
}
