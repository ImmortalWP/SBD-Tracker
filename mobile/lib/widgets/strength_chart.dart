import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/analytics_processor.dart';

class StrengthChart extends StatelessWidget {
  final Map<String, List<StrengthPoint>> data; // lift -> points
  final TimeRange range;

  const StrengthChart({super.key, required this.data, required this.range});

  static const _liftColors = {
    'Squat': AppTheme.accentRed,
    'Bench': AppTheme.accentBlue,
    'Deadlift': AppTheme.accentAmber,
  };

  @override
  Widget build(BuildContext context) {
    final allPoints = data.values.expand((v) => v).toList();
    if (allPoints.isEmpty) {
      return _emptyState('No strength data for this period');
    }

    final allValues = allPoints.map((p) => p.value).toList();
    final minY = (allValues.reduce((a, b) => a < b ? a : b) * 0.9).floorToDouble();
    final maxY = (allValues.reduce((a, b) => a > b ? a : b) * 1.05).ceilToDouble();

    // Build line data for each lift
    final lineBars = <LineChartBarData>[];
    for (final entry in data.entries) {
      final points = entry.value;
      if (points.isEmpty) continue;

      final color = _liftColors[entry.key] ?? AppTheme.text400;
      final spots = <FlSpot>[];

      for (int i = 0; i < points.length; i++) {
        spots.add(FlSpot(i.toDouble(), points[i].value));
      }

      lineBars.add(LineChartBarData(
        spots: spots,
        isCurved: true,
        curveSmoothness: 0.25,
        color: color,
        barWidth: 2.5,
        isStrokeCapRound: true,
        dotData: FlDotData(
          show: points.length <= 12,
          getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
            radius: 3,
            color: color,
            strokeWidth: 0,
          ),
        ),
        belowBarData: BarAreaData(
          show: true,
          color: color.withValues(alpha: 0.06),
        ),
      ));
    }

    // Use the longest series for bottom labels
    final longestSeries = data.values.reduce((a, b) => a.length >= b.length ? a : b);
    final labelInterval = _getLabelInterval(longestSeries.length);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLegend(),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              lineBarsData: lineBars,
              minY: minY,
              maxY: maxY,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: _getYInterval(minY, maxY),
                getDrawingHorizontalLine: (value) => FlLine(
                  color: AppTheme.bg800,
                  strokeWidth: 0.5,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    interval: _getYInterval(minY, maxY),
                    getTitlesWidget: (value, meta) {
                      if (value == meta.min || value == meta.max) return const SizedBox();
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Text(
                          '${value.toInt()}',
                          style: const TextStyle(fontSize: 10, color: AppTheme.text600),
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= longestSeries.length) return const SizedBox();
                      if (idx % labelInterval != 0 && idx != longestSeries.length - 1) return const SizedBox();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          longestSeries[idx].label,
                          style: const TextStyle(fontSize: 9, color: AppTheme.text600),
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                handleBuiltInTouches: true,
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (touchedSpot) => AppTheme.bg800,
                  tooltipRoundedRadius: 8,
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final liftName = data.keys.elementAt(spot.barIndex);
                      final color = _liftColors[liftName] ?? AppTheme.text400;
                      return LineTooltipItem(
                        '${liftName[0]}: ${spot.y.toStringAsFixed(0)}kg',
                        TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
                      );
                    }).toList();
                  },
                ),
              ),
            ),
            duration: const Duration(milliseconds: 150),
          ),
        ),
      ],
    );
  }

  Widget _buildLegend() {
    return Row(
      children: data.keys.map((lift) {
        final color = _liftColors[lift] ?? AppTheme.text400;
        return Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 3,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 5),
              Text(lift, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _emptyState(String message) {
    return Container(
      height: 160,
      alignment: Alignment.center,
      child: Text(message, style: const TextStyle(fontSize: 13, color: AppTheme.text600)),
    );
  }

  int _getLabelInterval(int count) {
    if (count <= 6) return 1;
    if (count <= 12) return 2;
    if (count <= 24) return 4;
    return (count / 6).ceil();
  }

  double _getYInterval(double minY, double maxY) {
    final range = maxY - minY;
    if (range <= 20) return 5;
    if (range <= 50) return 10;
    if (range <= 100) return 20;
    if (range <= 200) return 50;
    return 100;
  }
}
