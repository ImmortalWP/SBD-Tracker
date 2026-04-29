import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../services/analytics_processor.dart';
import '../theme/app_theme.dart';
import '../widgets/strength_chart.dart';
import '../widgets/volume_chart.dart';
import '../widgets/insights_widget.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  List<dynamic> _sessions = [];
  bool _loading = true;
  TimeRange _selectedRange = TimeRange.weeks4;

  @override
  void initState() {
    super.initState();
    _loadCached();
    _loadData();
  }

  Future<void> _loadCached() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('cache_analytics_v3');
    if (cached != null) {
      final data = jsonDecode(cached);
      if (mounted) {
        setState(() {
          _sessions = data['sessions'] ?? [];
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadData() async {
    try {
      final sessions = await ApiService.getSessions();
      sessions.sort((a, b) {
        final da = DateTime.tryParse(a['date']?.toString() ?? '') ?? DateTime(2000);
        final db = DateTime.tryParse(b['date']?.toString() ?? '') ?? DateTime(2000);
        return da.compareTo(db);
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cache_analytics_v3', jsonEncode({'sessions': sessions}));

      if (mounted) {
        setState(() {
          _sessions = sessions;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final processor = AnalyticsProcessor(_sessions);

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppTheme.accentRed,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        children: [
          // Title
          const Text(
            'Analytics',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.text50),
          ),
          const SizedBox(height: 20),

          // Time Range Selector
          _buildTimeRangeSelector(),
          const SizedBox(height: 28),

          if (_loading)
            const Padding(
              padding: EdgeInsets.all(60),
              child: Center(child: CircularProgressIndicator(color: AppTheme.text500, strokeWidth: 2)),
            )
          else if (_sessions.isEmpty)
            _buildEmptyState()
          else ...[
            // Strength Trend
            _sectionHeader('ESTIMATED 1RM TREND'),
            const SizedBox(height: 12),
            StrengthChart(
              data: {
                'Squat': processor.getStrengthTrend('Squat', _selectedRange),
                'Bench': processor.getStrengthTrend('Bench', _selectedRange),
                'Deadlift': processor.getStrengthTrend('Deadlift', _selectedRange),
              },
              range: _selectedRange,
            ),
            const SizedBox(height: 32),

            // Weekly Progress Summary
            _sectionHeader('PROGRESS'),
            const SizedBox(height: 12),
            _buildProgressSummary(processor),
            const SizedBox(height: 32),

            // Volume Trend
            _sectionHeader('VOLUME TREND'),
            const SizedBox(height: 12),
            VolumeChart(data: processor.getVolumeTrend(_selectedRange)),
            const SizedBox(height: 32),

            // Insights
            _sectionHeader('INSIGHTS'),
            const SizedBox(height: 12),
            InsightsWidget(insights: processor.getInsights(_selectedRange)),
          ],
        ],
      ),
    );
  }

  Widget _buildTimeRangeSelector() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppTheme.bg900,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.bg800, width: 0.5),
      ),
      child: Row(
        children: TimeRange.values.map((range) {
          final isSelected = range == _selectedRange;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedRange = range),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.bg700 : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  range.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? AppTheme.text50 : AppTheme.text500,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildProgressSummary(AnalyticsProcessor processor) {
    final progress = processor.getWeeklyProgress(_selectedRange);
    if (progress.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('Not enough data yet', style: TextStyle(fontSize: 13, color: AppTheme.text600)),
      );
    }

    return Column(
      children: progress.map((p) => _buildProgressRow(p)).toList(),
    );
  }

  Widget _buildProgressRow(LiftProgress p) {
    final liftColors = {
      'Squat': AppTheme.accentRed,
      'Bench': AppTheme.accentBlue,
      'Deadlift': AppTheme.accentAmber,
    };
    final color = liftColors[p.lift] ?? AppTheme.text400;

    String changeText;
    Color changeColor;
    IconData changeIcon;

    switch (p.trend) {
      case TrendDirection.up:
        changeText = '+${p.change.toStringAsFixed(0)}kg';
        changeColor = AppTheme.accentGreen;
        changeIcon = Icons.arrow_upward;
        break;
      case TrendDirection.down:
        changeText = '${p.change.toStringAsFixed(0)}kg';
        changeColor = AppTheme.accentRed;
        changeIcon = Icons.arrow_downward;
        break;
      case TrendDirection.plateau:
        changeText = 'Plateau';
        changeColor = AppTheme.accentAmber;
        changeIcon = Icons.horizontal_rule;
        break;
      case TrendDirection.flat:
        changeText = p.previous == 0 ? '—' : 'No change';
        changeColor = AppTheme.text500;
        changeIcon = Icons.horizontal_rule;
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          // Lift indicator
          Container(
            width: 4,
            height: 28,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          // Lift name
          SizedBox(
            width: 70,
            child: Text(
              p.lift,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.text200),
            ),
          ),
          // Current e1RM
          Expanded(
            child: Text(
              '${p.current.toStringAsFixed(0)}kg',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.text100,
                fontFamily: 'monospace',
              ),
            ),
          ),
          // Change
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(changeIcon, size: 14, color: changeColor),
              const SizedBox(width: 4),
              Text(
                changeText,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: changeColor,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppTheme.text500,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Icon(Icons.analytics_outlined, size: 48, color: AppTheme.text700),
          const SizedBox(height: 16),
          const Text(
            'No sessions logged yet',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.text400),
          ),
          const SizedBox(height: 6),
          const Text(
            'Start training to see your analytics',
            style: TextStyle(fontSize: 13, color: AppTheme.text600),
          ),
        ],
      ),
    );
  }
}
