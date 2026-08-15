import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/models/query_result.dart';
import '../../../core/models/table_meta.dart';
import '../../../core/providers.dart';
import '../../../core/theme/shadcn_tokens.dart';
import '../../../shared/empty_state.dart';
import '../../database/data/database_providers.dart';
import '../data/data_providers.dart';
import 'data_chart.dart';

/// 数据浏览页：数据库 → 表 → 列(多选) + TAG 过滤 + 聚合折线图 + 原始数据分页表格
class DataBrowsePage extends ConsumerStatefulWidget {
  const DataBrowsePage({super.key});

  @override
  ConsumerState<DataBrowsePage> createState() => _DataBrowsePageState();
}

class _DataBrowsePageState extends ConsumerState<DataBrowsePage> {
  static final DateFormat _timeFmt = DateFormat('yyyy-MM-dd HH:mm:ss.SSS');

  String? _db;
  String? _table;
  Set<String> _selected = {};
  Map<String, String> _tagValues = {};
  final Map<String, TextEditingController> _tagControllers = {};

  TimeRange _range = TimeRange.h24;
  String _interval = 'auto';
  TableQuery? _query;

  /// 用户手动操作过选择后不再跟随侧栏
  bool _userSet = false;

  /// 已处理过的列结果（用于仅在列加载完成时自动补选默认列一次）
  QueryResult? _defaultsHandled;

  String _resolvedInterval(TimeRange range, String interval) =>
      interval == 'auto' ? range.defaultInterval : interval;

  List<TableColumn> _currentColumns() {
    final table = _table;
    if (_db == null || table == null) return const [];
    final result = ref
        .read(columnListProvider(TableRef(_db!, table)))
        .value;
    if (result == null) return const [];
    return parseColumns(result);
  }

  String? _typeOf(String column) {
    for (final c in _currentColumns()) {
      if (c.name == column) return c.dataType;
    }
    return null;
  }

  void _resetSelection() {
    setState(() {
      _selected = {};
      _tagValues = {};
      _defaultsHandled = null;
      for (final c in _tagControllers.values) {
        c.dispose();
      }
      _tagControllers.clear();
      _query = null;
    });
  }

  void _onTableChanged(String? table) {
    setState(() => _table = table);
    _userSet = true;
    _defaultsHandled = null;
    _resetSelection();
  }

  void _execute() {
    final db = _db;
    final table = _table;
    if (db == null || table == null || _selected.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final start = now - _range.duration.inMilliseconds;
    final aggs = <String, String>{
      for (final c in _selected) c: aggregateFor(_typeOf(c) ?? ''),
    };
    _query = TableQuery(
      db: db,
      table: table,
      columns: _selected.toList(),
      columnAggs: aggs,
      tagFilters: {
        for (final e in _tagValues.entries)
          if (e.value.trim().isNotEmpty) e.key: e.value,
      },
      startMs: start,
      endMs: now,
      interval: _resolvedInterval(_range, _interval),
    );
    setState(() {});
  }

  void _refresh() {
    final q = _query;
    if (q == null) return;
    ref.invalidate(rawDataProvider(q));
    ref.invalidate(rawCountProvider(q));
    ref.invalidate(chartDataProvider(q));
  }

  void _goPage(int page) {
    final q = _query;
    if (q == null || page < 0) return;
    setState(() => _query = q.copyWith(page: page));
  }

  @override
  Widget build(BuildContext context) {
    final databases = ref.watch(databaseListProvider);
    final tables = _db == null
        ? const AsyncValue<QueryResult>.loading()
        : ref.watch(tableListProvider(_db!));
    final columns = _table == null
        ? const AsyncValue<QueryResult>.loading()
        : ref.watch(columnListProvider(TableRef(_db!, _table!)));

    final selDb = ref.watch(databaseSelectionProvider);
    final selTable = ref.watch(tableSelectionProvider);
    _syncSelection(selDb, selTable);
    _maybeDefaultColumns(columns);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildToolbar(databases, tables, columns),
        const Divider(height: 1),
        Expanded(flex: 3, child: _buildChartPane()),
        const Divider(height: 1),
        Expanded(flex: 2, child: _buildRawPane()),
      ],
    );
  }

  /// 未手动操作且侧栏有选择时，同步预填（防止覆盖用户手动选择）
  void _syncSelection(String? selDb, String? selTable) {
    if (_userSet || _query != null) return;
    if (selDb == null) return;
    if (_db == selDb && _table == selTable) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _userSet || _query != null) return;
      setState(() {
        _db = selDb;
        _table = selTable;
        _selected = {};
        _tagValues = {};
        _defaultsHandled = null;
        for (final c in _tagControllers.values) {
          c.dispose();
        }
        _tagControllers.clear();
      });
    });
  }

  /// 列加载完成后自动补选默认列（TAG + 前若干 FIELD 列），仅执行一次
  void _maybeDefaultColumns(AsyncValue<QueryResult> columns) {
    if (_query != null || _table == null || _selected.isNotEmpty) return;
    final r = columns.value;
    if (r == null || identical(r, _defaultsHandled)) return;
    _defaultsHandled = r;
    final cols = parseColumns(r);
    if (cols.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _query != null || _selected.isNotEmpty) return;
      final defaultSelected = <String>{
        for (final c in cols)
          if (c.category == ColumnCategory.tag) c.name,
        for (final c in cols)
          if (c.category == ColumnCategory.field) c.name,
      }.take(24).toSet();
      if (defaultSelected.isNotEmpty) {
        setState(() => _selected = defaultSelected);
      }
    });
  }

  Widget _buildToolbar(
    AsyncValue<QueryResult> databases,
    AsyncValue<QueryResult> tables,
    AsyncValue<QueryResult> columns,
  ) {
    final colList = _table == null
        ? const <TableColumn>[]
        : parseColumns(
            columns.value ??
                const QueryResult(
                  columnNames: [],
                  rows: [],
                  dataTypes: [],
                  elapsedMs: 0,
                ),
          );
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ShadTokens.space4,
        vertical: ShadTokens.space2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: ShadTokens.space2,
            runSpacing: ShadTokens.space2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Icon(
                RemixIcons.bar_chart_2_line,
                size: 16,
                color: ShadTokens.primary,
              ),
              const SizedBox(width: ShadTokens.space1),
              _select(
                '数据库',
                _db,
                databases,
                (v) {
                  setState(() => _db = v);
                  _userSet = true;
                  _onTableChanged(null);
                },
              ),
              _select(
                '表',
                _table,
                tables,
                _onTableChanged,
              ),
              const SizedBox(width: ShadTokens.space2),
              SegmentedButton<TimeRange>(
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                segments: const [
                  ButtonSegment(value: TimeRange.h1, label: Text('1h')),
                  ButtonSegment(value: TimeRange.h6, label: Text('6h')),
                  ButtonSegment(value: TimeRange.h24, label: Text('24h')),
                  ButtonSegment(value: TimeRange.d7, label: Text('7d')),
                  ButtonSegment(value: TimeRange.d30, label: Text('30d')),
                ],
                selected: {_range},
                onSelectionChanged: (s) => setState(() => _range = s.first),
              ),
              const SizedBox(width: ShadTokens.space2),
              DropdownButton<String>(
                value: _interval,
                underline: const SizedBox.shrink(),
                isDense: true,
                style: const TextStyle(
                  fontSize: 13,
                  color: ShadTokens.foreground,
                ),
                items: [
                  for (final o in intervalOptions)
                    DropdownMenuItem(
                      value: o,
                      child: Text(o == 'auto' ? '间隔：自动' : '间隔：$o'),
                    ),
                ],
                onChanged: (v) => setState(() => _interval = v ?? 'auto'),
              ),
              FilledButton.icon(
                onPressed: _execute,
                icon: const Icon(RemixIcons.play_line, size: 16),
                label: const Text('查询'),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: '刷新',
                onPressed: _refresh,
                icon: const Icon(RemixIcons.refresh_line, size: 18),
              ),
            ],
          ),
          if (_table != null && colList.isNotEmpty) ...[
            const SizedBox(height: ShadTokens.space2),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in colList)
                  if (c.category != ColumnCategory.time)
                    FilterChip(
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        '${c.name} · ${c.category.label}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      selected: _selected.contains(c.name),
                      onSelected: (on) {
                        _userSet = true;
                        setState(() {
                          on
                              ? _selected.add(c.name)
                              : _selected.remove(c.name);
                          _query = null;
                        });
                      },
                      showCheckmark: false,
                      selectedColor: c.category == ColumnCategory.tag
                          ? ShadTokens.warning.withValues(alpha: 0.25)
                          : c.category == ColumnCategory.field
                          ? ShadTokens.success.withValues(alpha: 0.2)
                          : ShadTokens.primary.withValues(alpha: 0.15),
                      side: BorderSide(
                        color: _selected.contains(c.name)
                            ? c.category == ColumnCategory.tag
                                  ? ShadTokens.warning
                                  : c.category == ColumnCategory.field
                                  ? ShadTokens.success
                                  : ShadTokens.primary
                            : ShadTokens.border,
                      ),
                    ),
              ],
            ),
          ],
          if (_table != null && colList.any((c) => c.category == ColumnCategory.tag)) ...[
            const SizedBox(height: ShadTokens.space2),
            Wrap(
              spacing: ShadTokens.space2,
              runSpacing: ShadTokens.space2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  '标签过滤：',
                  style: TextStyle(
                    fontSize: 12,
                    color: ShadTokens.mutedForeground,
                  ),
                ),
                for (final c in colList)
                  if (c.category == ColumnCategory.tag)
                    SizedBox(
                      width: 150,
                      child: TextField(
                        controller: _tagController(c.name),
                        onChanged: (v) {
                          _userSet = true;
                          _tagValues[c.name] = v;
                          _query = null;
                          setState(() {});
                        },
                        decoration: InputDecoration(
                          labelText: c.name,
                          isDense: true,
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: ShadTokens.space2,
                            vertical: 6,
                          ),
                        ),
                      ),
                    ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  TextEditingController _tagController(String name) {
    return _tagControllers.putIfAbsent(
      name,
      () => TextEditingController(text: _tagValues[name] ?? ''),
    );
  }

  Widget _select(
    String label,
    String? value,
    AsyncValue<QueryResult> data,
    ValueChanged<String?> onChanged,
  ) {
    final values = data.value == null
        ? <String>[]
        : [for (final row in data.value!.rows) '${row.first}'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: ShadTokens.space2),
      decoration: BoxDecoration(
        border: Border.all(color: ShadTokens.divider),
        borderRadius: BorderRadius.circular(ShadTokens.radiusDefault),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          hint: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: ShadTokens.placeholder,
            ),
          ),
          value: values.contains(value) ? value : null,
          isDense: true,
          isExpanded: false,
          style: const TextStyle(fontSize: 13, color: ShadTokens.foreground),
          items: [
            for (final v in values) DropdownMenuItem(value: v, child: Text(v)),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildChartPane() {
    final q = _query;
    if (q == null) {
      return const EmptyState(
        icon: RemixIcons.bar_chart_2_line,
        title: '选择表与列并点击「查询」查看数据',
        description: '折线图展示聚合趋势，下方表格展示原始数据',
      );
    }
    final chart = ref.watch(chartDataProvider(q));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            ShadTokens.space4,
            ShadTokens.space2,
            ShadTokens.space4,
            0,
          ),
          child: Row(
            children: [
              const Icon(
                RemixIcons.line_chart_line,
                size: 15,
                color: ShadTokens.primary,
              ),
              const SizedBox(width: ShadTokens.space2),
              Expanded(
                child: Text(
                  '${q.db}.${q.table} · ${q.columns.join(', ')} · ${q.interval} 窗口',
                  style: const TextStyle(
                    fontSize: ShadTokens.fontBody,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                _range.label,
                style: const TextStyle(
                  fontSize: ShadTokens.fontAux,
                  color: ShadTokens.mutedForeground,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: chart.when(
            loading: () =>
                const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(ShadTokens.space4),
                child: Text(
                  '聚合查询失败：$e',
                  style: const TextStyle(color: ShadTokens.destructive),
                ),
              ),
            ),
            data: (r) => DataChart(
              series: chartSeries(r),
              startMs: q.startMs,
              endMs: q.endMs,
              title: q.interval,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRawPane() {
    final q = _query;
    if (q == null) {
      return const EmptyState(
        icon: RemixIcons.table_line,
        title: '原始数据将在此展示',
        description: '分页预览该表在时间范围内的原始数据',
      );
    }
    final raw = ref.watch(rawDataProvider(q));
    final count = ref.watch(rawCountProvider(q));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            ShadTokens.space4,
            ShadTokens.space2,
            ShadTokens.space4,
            0,
          ),
          child: Row(
            children: [
              const Icon(
                RemixIcons.database_2_line,
                size: 15,
                color: ShadTokens.primary,
              ),
              const SizedBox(width: ShadTokens.space2),
              const Text(
                '原始数据',
                style: TextStyle(
                  fontSize: ShadTokens.fontBody,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                count.when(
                  data: (n) => '共 $n 行',
                  loading: () => '统计中…',
                  error: (_, _) => '',
                ),
                style: const TextStyle(
                  fontSize: ShadTokens.fontAux,
                  color: ShadTokens.mutedForeground,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: raw.when(
            loading: () =>
                const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(ShadTokens.space4),
                child: Text(
                  '查询失败：$e',
                  style: const TextStyle(color: ShadTokens.destructive),
                ),
              ),
            ),
            data: (r) => _buildRawTable(r, q, count.value ?? 0),
          ),
        ),
      ],
    );
  }

  Widget _buildRawTable(QueryResult r, TableQuery q, int total) {
    final pageCount = total <= 0 ? 1 : ((total - 1) ~/ q.pageSize) + 1;
    return Column(
      children: [
        Expanded(
          child: r.rows.isEmpty
              ? const EmptyState(
                  title: '时间范围内无原始数据',
                  icon: Icons.inbox_outlined,
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: DataTable(
                      headingRowColor: WidgetStatePropertyAll(
                        ShadTokens.muted,
                      ),
                      horizontalMargin: ShadTokens.space4,
                      columnSpacing: ShadTokens.space4,
                      columns: [
                        for (final c in r.columnNames)
                          DataColumn(label: Text(c)),
                      ],
                      rows: [
                        for (final row in r.rows)
                          DataRow(
                            cells: [
                              for (var i = 0; i < r.columnNames.length; i++)
                                DataCell(
                                  Text(
                                    i < row.length
                                        ? _format(i, r.columnNames, row[i])
                                        : '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: ShadTokens.space4,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: ShadTokens.divider)),
            color: ShadTokens.card,
          ),
          child: Row(
            children: [
              Text(
                '${r.rows.length} 行/页 · 第 ${q.page + 1} / $pageCount 页',
                style: const TextStyle(
                  fontSize: ShadTokens.fontAux,
                  color: ShadTokens.mutedForeground,
                ),
              ),
              const Spacer(),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_left, size: 18),
                onPressed: q.page > 0 ? () => _goPage(q.page - 1) : null,
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_right, size: 18),
                onPressed: q.page < pageCount - 1
                    ? () => _goPage(q.page + 1)
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _format(int col, List<String> columns, dynamic value) {
    if (value == null) return 'null';
    final colName = col < columns.length ? columns[col] : '';
    if ((colName == 'Time' || colName == 'time') && value is int) {
      try {
        return _timeFmt.format(DateTime.fromMillisecondsSinceEpoch(value));
      } catch (_) {}
    }
    if (value is double && value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toString();
  }

  @override
  void dispose() {
    for (final c in _tagControllers.values) {
      c.dispose();
    }
    super.dispose();
  }
}
