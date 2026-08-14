import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/models/query_result.dart';
import '../../../core/theme/tdesign_tokens.dart';
import '../../../shared/empty_state.dart';

/// 将聚合查询结果解析为折线数据点（x=Time 毫秒时间戳，y=聚合值）
List<FlSpot> chartSpots(QueryResult r) {
  final iTime = r.columnNames.indexOf('Time');
  final iVal = r.columnNames.length - 1;
  final spots = <FlSpot>[];
  for (var i = 0; i < r.rows.length; i++) {
    final row = r.rows[i];
    final x = iTime >= 0 ? double.tryParse('${row[iTime]}') : i.toDouble();
    final y = double.tryParse('${row[iVal]}');
    if (x != null && y != null) spots.add(FlSpot(x, y));
  }
  return spots;
}

/// 聚合折线图（fl_chart）
class DataChart extends StatelessWidget {
  final List<FlSpot> spots;
  final int startMs;
  final int endMs;
  final String title;

  const DataChart({
    super.key,
    required this.spots,
    required this.startMs,
    required this.endMs,
    required this.title,
  });

  String _formatX(double v) {
    final dt = DateTime.fromMillisecondsSinceEpoch(v.toInt());
    final wide = (endMs - startMs) > const Duration(hours: 24).inMilliseconds;
    return wide
        ? DateFormat('MM-dd\nHH:mm').format(dt)
        : DateFormat('HH:mm').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    if (spots.isEmpty) {
      return const EmptyState(
        icon: Icons.show_chart,
        title: '时间范围内无聚合数据',
        description: '可尝试扩大时间范围或更换聚合间隔',
      );
    }
    final ys = spots.map((s) => s.y);
    final minY = ys.reduce((a, b) => a < b ? a : b);
    final maxY = ys.reduce((a, b) => a > b ? a : b);
    final yRange = maxY - minY;
    final pad = yRange == 0
        ? (maxY.abs() * 0.1).clamp(1.0, double.infinity)
        : yRange * 0.1;

    return Padding(
      padding: const EdgeInsets.all(TdTokens.space3),
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
                FlLine(color: TdTokens.divider, strokeWidth: 1),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: TdTokens.divider),
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
                      color: TdTokens.textSecondary,
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
                        color: TdTokens.textSecondary,
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
            LineChartBarData(
              spots: spots,
              isCurved: true,
              preventCurveOverShooting: true,
              color: TdTokens.brand,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: TdTokens.brand.withValues(alpha: 0.08),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatNumber(double v) {
    if (v == v.roundToDouble() && v.abs() < 1e15) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }
}
