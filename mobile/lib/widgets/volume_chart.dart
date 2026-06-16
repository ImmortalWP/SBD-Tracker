import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/analytics_processor.dart';

class VolumeChart extends StatelessWidget {
  final List<VolumePoint> data;

  const VolumeChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Container(
        height: 140,
        alignment: Alignment.center,
        child: const Text('No volume data', style: TextStyle(fontSize: 13, color: AppTheme.text600)),
      );
    }

    final maxVol = data.map((p) => p.volume).reduce((a, b) => a > b ? a : b);
    final minVol = 0.0;

    return SizedBox(
      height: 160,
      child: BarChart(
        BarChartData(
          maxY: maxVol * 1.15,
          minY: minVol,
          barGroups: _buildBars(maxVol),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: _getInterval(maxVol),
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
                reservedSize: 44,
                interval: _getInterval(maxVol),
                getTitlesWidget: (value, meta) {
                  if (value == 0) return const SizedBox();
                  if (value == meta.max) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(
                      _formatVolume(value),
                      style: const TextStyle(fontSize: 9, color: AppTheme.text600),
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= data.length) return const SizedBox();
                  // Show every label if few bars, else skip
                  final interval = data.length <= 8 ? 1 : 2;
                  if (idx % interval != 0 && idx != data.length - 1) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      data[idx].label,
                      style: const TextStyle(fontSize: 9, color: AppTheme.text600),
                    ),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (group) => AppTheme.bg800,
              tooltipRoundedRadius: 8,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  _formatVolume(rod.toY),
                  const TextStyle(color: AppTheme.text100, fontSize: 11, fontWeight: FontWeight.w600),
                );
              },
            ),
          ),
        ),
        duration: const Duration(milliseconds: 150),
      ),
    );
  }

  List<BarChartGroupData> _buildBars(double maxVol) {
    return List.generate(data.length, (i) {
      // Color intensity based on relative volume
      final ratio = maxVol > 0 ? data[i].volume / maxVol : 0.0;
      final color = Color.lerp(
        AppTheme.accentBlue.withValues(alpha: 0.4),
        AppTheme.accentBlue,
        ratio,
      )!;

      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: data[i].volume,
            color: color,
            width: data.length <= 6 ? 20 : (data.length <= 12 ? 14 : 8),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    });
  }

  String _formatVolume(double vol) {
    if (vol >= 1000) {
      return '${(vol / 1000).toStringAsFixed(1)}k';
    }
    return vol.toStringAsFixed(0);
  }

  double _getInterval(double maxVol) {
    if (maxVol <= 5000) return 1000;
    if (maxVol <= 20000) return 5000;
    if (maxVol <= 50000) return 10000;
    if (maxVol <= 100000) return 25000;
    return 50000;
  }
}
