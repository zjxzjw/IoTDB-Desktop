import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/models/query_result.dart';
import '../../../core/theme/shadcn_tokens.dart';
import '../../../shared/empty_state.dart';

/// 单条折线序列
class ChartSeries {
  final String name;
  final List<FlSpot> spots;

  const ChartSeries(this.name, this.spots);
}

/// 将聚合查询结果解析为多条折线（x=Time 毫秒时间戳，y=聚合值）
List<ChartSeries> chartSeries(QueryResult r) {
  final iTime = r.columnNames.indexWhere(
    (n) => n.toLowerCase() == 'time',
  );
  final series = <ChartSeries>[];
  for (var i = 0; i < r.columnNames.length; i++) {
    if (i == iTime) continue;
    final spots = <FlSpot>[];
    for (final row in r.rows) {
      final x = iTime >= 0 && iTime < row.length
          ? double.tryParse('${row[iTime]}')
          : null;
      final y = i < row.length ? double.tryParse('${row[i]}') : null;
      if (x != null && y != null) spots.add(FlSpot(x, y));
    }
    series.add(ChartSeries(r.columnNames[i], spots));
  }
  return series;
}

/// 多序列聚合折线图（fl_chart）
class DataChart extends StatelessWidget {
  final List<ChartSeries> series;
  final int startMs;
  final int endMs;
  final String title;

  const DataChart({
    super.key,
    required this.series,
    required this.startMs,
    required this.endMs,
    required this.title,
  });

  static const List<Color> _palette = [
    ShadTokens.primary,
    Color(0xFF0E9F6E),
    Color(0xFFF59E0B),
    Color(0xFFE02424),
    Color(0xFF7C3AED),
    Color(0xFF3B82F6),
    Color(0xFF0891B2),
    Color(0xFFA855F7),
  ];

  String _formatX(double v) {
    final dt = DateTime.fromMillisecondsSinceEpoch(v.toInt());
    final wide = (endMs - startMs) > const Duration(hours: 24).inMilliseconds;
    return wide
        ? DateFormat('MM-dd\nHH:mm').format(dt)
        : DateFormat('HH:mm').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final visible = [
      for (final s in series)
        if (s.spots.isNotEmpty) s,
    ];
    if (visible.isEmpty) {
      return const EmptyState(
        icon: Icons.show_chart,
        title: '时间范围内无聚合数据',
        description: '可尝试扩大时间范围或更换聚合间隔',
      );
    }
    final allYs = [for (final s in visible) ...s.spots.map((e) => e.y)];
    final minY = allYs.reduce((a, b) => a < b ? a : b);
    final maxY = allYs.reduce((a, b) => a > b ? a : b);
    final yRange = maxY - minY;
    final pad = yRange == 0
        ? (maxY.abs() * 0.1).clamp(1.0, double.infinity)
        : yRange * 0.1;

    return Padding(
      padding: const EdgeInsets.all(ShadTokens.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (visible.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: ShadTokens.space2),
              child: Wrap(
                spacing: ShadTokens.space3,
                runSpacing: 4,
                children: [
                  for (var i = 0; i < visible.length; i++)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _palette[i % _palette.length],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${visible[i].name} · $title',
                          style: const TextStyle(
                            fontSize: 11,
                            color: ShadTokens.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          Expanded(
            child: LineChart(
              LineChartData(
                minX: startMs.toDouble(),
                maxX: endMs.toDouble(),
                minY: (minY - pad).toDouble(),
                maxY: (maxY + pad).toDouble(),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: yRange == 0 ? null : yRange / 4,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: ShadTokens.divider, strokeWidth: 1),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: ShadTokens.divider),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      interval: yRange == 0 ? null : yRange / 4,
                      getTitlesWidget: (v, meta) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Text(
                          _formatNumber(v),
                          style: const TextStyle(
                            fontSize: 10,
                            color: ShadTokens.mutedForeground,
                          ),
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 34,
                      getTitlesWidget: (v, meta) {
                        if (meta.formattedValue == 'min' ||
                            meta.formattedValue == 'max') {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            _formatX(v),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 10,
                              color: ShadTokens.mutedForeground,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) => [
                      for (final s in spots)
                        LineTooltipItem(
                          '${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.fromMillisecondsSinceEpoch(s.x.toInt()))}\n${_formatNumber(s.y)}',
                          const TextStyle(fontSize: 11, color: Colors.white),
                        ),
                    ],
                  ),
                ),
                lineBarsData: [
                  for (var i = 0; i < visible.length; i++)
                    LineChartBarData(
                      spots: visible[i].spots,
                      isCurved: true,
                      preventCurveOverShooting: true,
                      color: _palette[i % _palette.length],
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: _palette[i % _palette.length].withValues(
                          alpha: 0.08,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatNumber(double v) {
    if (v == v.roundToDouble() && v.abs() < 1e15) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }
}
