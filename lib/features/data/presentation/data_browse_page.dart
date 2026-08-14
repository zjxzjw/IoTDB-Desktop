import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/models/query_result.dart';
import '../../../core/providers.dart';
import '../../../core/theme/shadcn_tokens.dart';
import '../../../shared/empty_state.dart';
import '../../database/data/database_providers.dart';
import '../data/data_providers.dart';
import 'data_chart.dart';

/// 数据浏览页：测点选择 + 聚合折线图 + 原始数据分页表格
class DataBrowsePage extends ConsumerStatefulWidget {
  const DataBrowsePage({super.key});

  @override
  ConsumerState<DataBrowsePage> createState() => _DataBrowsePageState();
}

class _DataBrowsePageState extends ConsumerState<DataBrowsePage> {
  static final DateFormat _timeFmt = DateFormat('yyyy-MM-dd HH:mm:ss.SSS');

  String? _db;
  String? _device;
  String? _sensor;
  String? _sensorType;
  TimeRange _range = TimeRange.h24;
  String _interval = 'auto';
  DataQuery? _query;

  String _resolvedInterval(TimeRange range, String interval) =>
      interval == 'auto' ? range.defaultInterval : interval;

  void _execute() {
    if (_db == null || _device == null || _sensor == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final start = now - _range.duration.inMilliseconds;
    _query = DataQuery(
      device: _device!,
      timeseries: _sensor!,
      startMs: start,
      endMs: now,
      interval: _resolvedInterval(_range, _interval),
      aggregate: aggregateFor(_sensorType ?? ''),
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
    final devices = _db == null
        ? const AsyncValue<QueryResult>.loading()
        : ref.watch(deviceListProvider(_db!));
    final timeseries = _device == null
        ? const AsyncValue<QueryResult>.loading()
        : ref.watch(timeseriesListProvider(_device!));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildToolbar(databases, devices, timeseries),
        const Divider(height: 1),
        Expanded(flex: 3, child: _buildChartPane()),
        const Divider(height: 1),
        Expanded(flex: 2, child: _buildRawPane()),
      ],
    );
  }

  Widget _buildToolbar(
    AsyncValue<QueryResult> databases,
    AsyncValue<QueryResult> devices,
    AsyncValue<QueryResult> timeseries,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ShadTokens.space4,
        vertical: ShadTokens.space2,
      ),
      child: Wrap(
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
            (v) => setState(() {
              _db = v;
              _device = null;
              _sensor = null;
              _sensorType = null;
            }),
          ),
          _select(
            '设备',
            _device,
            devices,
            (v) => setState(() {
              _device = v;
              _sensor = null;
              _sensorType = null;
            }),
          ),
          _select(
            '测点',
            _sensor,
            timeseries,
            (v) => setState(() => _sensor = v),
            valuesBuilder: (r) => [for (final row in r.rows) '${row.first}'],
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
            style: const TextStyle(fontSize: 13, color: ShadTokens.foreground),
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
    );
  }

  Widget _select(
    String label,
    String? value,
    AsyncValue<QueryResult> data,
    ValueChanged<String?> onChanged, {
    List<String> Function(QueryResult)? valuesBuilder,
  }) {
    final values = data.value == null
        ? <String>[]
        : (valuesBuilder?.call(data.value!) ??
              [for (final row in data.value!.rows) '${row.first}']);
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
        title: '选择测点并点击「查询」查看数据',
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
                  '${q.aggregate.toUpperCase()}(${q.sensorName}) · ${q.interval} 窗口',
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
              spots: chartSpots(r),
              startMs: q.startMs,
              endMs: q.endMs,
              title: q.sensorName,
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
        description: '分页预览该测点在时间范围内的原始数据',
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

  Widget _buildRawTable(QueryResult r, DataQuery q, int total) {
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
    if (value is double && value == value.roundToDouble())
      return value.toInt().toString();
    return value.toString();
  }
}
