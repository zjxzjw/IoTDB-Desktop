import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/theme/shadcn_tokens.dart';
import 'empty_state.dart';

/// 通用结果表格：铺满宽度 + 固定表头 + 分页 + Time 列格式化 + 底部统计
///
/// 手写实现：表头行固定在顶部（不随纵向滚动），正文独立纵向滚动；
/// 列宽 = max(最小宽, 视口宽/列数)，列少时铺满、列多时横向滚动（表头与正文同宽对齐）。
/// 拖拽表头右缘可调整列宽，双击重置为自适应宽度。
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
  static const double _minColWidth = 120;
  static const double _minResizeWidth = 60;
  static const double _handleWidth = 8;

  int _page = 0;

  /// 每列自定义宽度，null 表示跟随默认自适应宽度
  late List<double?> _customWidths;

  @override
  void initState() {
    super.initState();
    _customWidths = List<double?>.filled(widget.columns.length, null);
  }

  @override
  void didUpdateWidget(ResultTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.columns.length != widget.columns.length) {
      _customWidths = List<double?>.filled(widget.columns.length, null);
    }
  }

  int get _pageCount => ((widget.rows.length - 1) ~/ widget.pageSize) + 1;

  String _format(int col, dynamic value) {
    if (value == null) return 'null';
    final colName = col < widget.columns.length ? widget.columns[col] : '';
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
          child: Padding(
            padding: const EdgeInsets.only(top: ShadTokens.space2),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final viewport = constraints.maxWidth;
                final colCount = widget.columns.length;
                final baseWidth = math.max(
                  _minColWidth,
                  colCount == 0 ? _minColWidth : viewport / colCount,
                );
                final widths = [
                  for (var i = 0; i < colCount; i++)
                    _customWidths[i] ?? baseWidth,
                ];
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: viewport),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(widths),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                for (final row in pageRows)
                                  _buildRow(row, widths),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        _buildFooter(),
      ],
    );
  }

  Widget _buildHeader(List<double> widths) {
    return Container(
      color: ShadTokens.muted,
      child: Row(
        children: [
          for (var i = 0; i < widget.columns.length; i++)
            SizedBox(
              key: ValueKey('result-col-$i'),
              width: widths[i],
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: ShadTokens.space2,
                      vertical: 8,
                    ),
                    child: Text(
                      widget.columns[i],
                      style: const TextStyle(
                        fontSize: ShadTokens.fontBody,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    width: _handleWidth,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeColumn,
                      child: GestureDetector(
                        key: ValueKey('result-col-resize-$i'),
                        behavior: HitTestBehavior.opaque,
                        onHorizontalDragUpdate: (d) {
                          setState(() {
                            _customWidths[i] = ((_customWidths[i] ??
                                        widths[i]) +
                                    d.delta.dx)
                                .clamp(_minResizeWidth, double.infinity)
                                .toDouble();
                          });
                        },
                        onDoubleTap: () {
                          setState(() => _customWidths[i] = null);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRow(List<dynamic> row, List<double> widths) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: ShadTokens.divider)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < widget.columns.length; i++)
            SizedBox(
              width: widths[i],
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: ShadTokens.space2,
                  vertical: 6,
                ),
                child: Text(
                  i < row.length ? _format(i, row[i]) : '',
                  style: TextStyle(
                    fontSize: ShadTokens.fontBody,
                    color: i < row.length && row[i] == null
                        ? ShadTokens.placeholder
                        : ShadTokens.foreground,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    final multiplePages = _pageCount > 1;
    return Container(
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
            '共 ${widget.rows.length} 行'
            '${widget.elapsedMs != null ? ' · ${widget.elapsedMs}ms' : ''}',
            style: const TextStyle(
              fontSize: ShadTokens.fontAux,
              color: ShadTokens.mutedForeground,
            ),
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
              style: const TextStyle(
                fontSize: ShadTokens.fontAux,
                color: ShadTokens.mutedForeground,
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.chevron_right, size: 18),
              onPressed: _page < _pageCount - 1
                  ? () => setState(() => _page++)
                  : null,
            ),
          ],
        ],
      ),
    );
  }
}