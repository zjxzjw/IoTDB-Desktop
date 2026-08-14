import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/shadcn_tokens.dart';
import 'empty_state.dart';

/// 通用结果表格：分页 + 横向滚动 + Time 列格式化 + 底部统计
class ResultTable extends StatefulWidget {
  final List<String> columns;
  final List<List<dynamic>> rows;
  final int? elapsedMs;
  final int pageSize;

  const ResultTable({
    super.key,
    required this.columns,
    required this.rows,
    this.elapsedMs,
    this.pageSize = 100,
  });

  @override
  State<ResultTable> createState() => _ResultTableState();
}

class _ResultTableState extends State<ResultTable> {
  static final DateFormat _timeFmt = DateFormat('yyyy-MM-dd HH:mm:ss.SSS');
  int _page = 0;

  int get _pageCount => ((widget.rows.length - 1) ~/ widget.pageSize) + 1;

  String _format(int col, dynamic value) {
    if (value == null) return 'null';
    final colName = col < widget.columns.length ? widget.columns[col] : '';
    if ((colName == 'Time' || colName == 'time') && value is int) {
      try {
        return _timeFmt.format(DateTime.fromMillisecondsSinceEpoch(value));
      } catch (_) {}
    }
    if (value is double && value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final rows = widget.rows;
    if (rows.isEmpty) {
      return const EmptyState(title: '查询结果为空', icon: Icons.table_rows_outlined);
    }
    final start = _page * widget.pageSize;
    final pageRows = rows.skip(start).take(widget.pageSize).toList();

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: DataTable(
                headingRowColor: WidgetStatePropertyAll(ShadTokens.muted),
                horizontalMargin: ShadTokens.space4,
                columnSpacing: ShadTokens.space4,
                columns: [
                  for (final name in widget.columns) DataColumn(label: Text(name)),
                ],
                rows: [
                  for (final row in pageRows)
                    DataRow(
                      cells: [
                        for (var i = 0; i < widget.columns.length; i++)
                          DataCell(
                            Text(
                              i < row.length ? _format(i, row[i]) : '',
                              style: TextStyle(
                                fontSize: ShadTokens.fontBody,
                                color: i < row.length && row[i] == null ? ShadTokens.placeholder : ShadTokens.foreground,
                              ),
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
        _buildFooter(),
      ],
    );
  }

  Widget _buildFooter() {
    final multiplePages = _pageCount > 1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: ShadTokens.space4, vertical: 6),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: ShadTokens.divider)),
        color: ShadTokens.card,
      ),
      child: Row(
        children: [
          Text(
            '共 ${widget.rows.length} 行${widget.elapsedMs != null ? ' · ${widget.elapsedMs}ms' : ''}',
            style: const TextStyle(fontSize: ShadTokens.fontAux, color: ShadTokens.mutedForeground),
          ),
          const Spacer(),
          if (multiplePages) ...[
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.chevron_left, size: 18),
              onPressed: _page > 0 ? () => setState(() => _page--) : null,
            ),
            Text(
              '${_page + 1} / $_pageCount',
              style: const TextStyle(fontSize: ShadTokens.fontAux, color: ShadTokens.mutedForeground),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.chevron_right, size: 18),
              onPressed: _page < _pageCount - 1 ? () => setState(() => _page++) : null,
            ),
          ],
        ],
      ),
    );
  }
}
