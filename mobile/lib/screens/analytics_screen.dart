import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';
import '../services/analytics_processor.dart';
import '../theme/app_theme.dart';
import '../widgets/strength_chart.dart';
import '../widgets/volume_chart.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  List<dynamic> _sessions = [];
  bool _loading = true;
  TimeRange _selectedRange = TimeRange.thisYear;
  String _selectedLift = 'Squat';

  @override
  void initState() {
    super.initState();
    _loadCached();
    _loadData();
  }

  Future<void> _loadCached() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('cache_analytics_v4');
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
      await prefs.setString('cache_analytics_v4', jsonEncode({'sessions': sessions}));

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
    final canPop = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: AppTheme.bg950,
      appBar: canPop ? AppBar(
        backgroundColor: AppTheme.bg950,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppTheme.text100, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ) : null,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppTheme.accentBlue,
          backgroundColor: AppTheme.bg850,
          child: ListView(
            padding: EdgeInsets.fromLTRB(20, canPop ? 0 : 24, 20, 100),
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildLiftSelector(),
              const SizedBox(height: 24),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(60),
                  child: Center(child: CircularProgressIndicator(color: AppTheme.accentBlue, strokeWidth: 2)),
                )
              else if (_sessions.isEmpty)
                _buildEmptyState()
              else ...[
                _buildStrengthChart(processor),
                const SizedBox(height: 16),
                _buildKeyMetrics(processor),
                const SizedBox(height: 24),
                _buildVolumeChart(processor),
                const SizedBox(height: 24),
                _buildTopLifts(processor),
                const SizedBox(height: 24),
                _buildInsights(processor),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Analytics',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.text50),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.bg850,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.bg800),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<TimeRange>(
              value: _selectedRange,
              dropdownColor: AppTheme.bg850,
              icon: const Icon(Icons.keyboard_arrow_down, color: AppTheme.text400, size: 16),
              isDense: true,
              style: const TextStyle(fontSize: 13, color: AppTheme.text200, fontWeight: FontWeight.w500),
              onChanged: (TimeRange? newValue) {
                if (newValue != null) {
                  setState(() => _selectedRange = newValue);
                }
              },
              items: [
                TimeRange.days7, TimeRange.days30, TimeRange.thisBlock, TimeRange.thisMonth, TimeRange.thisYear
              ].map<DropdownMenuItem<TimeRange>>((TimeRange value) {
                return DropdownMenuItem<TimeRange>(
                  value: value,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 12, color: AppTheme.text500),
                        const SizedBox(width: 6),
                        Text(value.label),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLiftSelector() {
    final lifts = [
      {'name': 'Squat', 'icon': Icons.sports_gymnastics},
      {'name': 'Bench', 'icon': Icons.airline_seat_flat_angled},
      {'name': 'Deadlift', 'icon': Icons.fitness_center},
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bg900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.bg800),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: lifts.map((lift) {
          final isSelected = _selectedLift == lift['name'];
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedLift = lift['name'] as String),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.accentBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(lift['icon'] as IconData, size: 16, color: isSelected ? Colors.white : AppTheme.text500),
                    const SizedBox(width: 8),
                    Text(
                      lift['name'] as String,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        color: isSelected ? Colors.white : AppTheme.text400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStrengthChart(AnalyticsProcessor processor) {
    final data = processor.getStrengthTrend(_selectedLift, _selectedRange);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bg850,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.bg800),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Strength Progress (Top Set)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.text50)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.bg900,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: const [
                    Text('1RM Trend', style: TextStyle(fontSize: 11, color: AppTheme.text400)),
                    SizedBox(width: 4),
                    Icon(Icons.keyboard_arrow_down, size: 14, color: AppTheme.text400),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          StrengthChart(
            data: {_selectedLift: data},
            range: _selectedRange,
          ),
        ],
      ),
    );
  }

  Widget _buildKeyMetrics(AnalyticsProcessor processor) {
    final metrics = processor.getLiftMetrics(_selectedLift, _selectedRange);
    
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      children: [
        _buildMetricCard(
          'Current Max',
          '${metrics.currentMax.toStringAsFixed(0)} kg',
          null, // Or add date of max
          AppTheme.accentBlue,
          Icons.emoji_events,
        ),
        _buildMetricCard(
          'Est. 1RM',
          '${metrics.est1RM.toStringAsFixed(0)} kg',
          metrics.prevEst1RM > 0 ? '${metrics.est1RM >= metrics.prevEst1RM ? '+' : ''}${(metrics.est1RM - metrics.prevEst1RM).toStringAsFixed(0)} kg vs last period' : null,
          AppTheme.accentGreen,
          Icons.trending_up,
        ),
        _buildMetricCard(
          'Volume (7d)',
          '${NumberFormat('#,##0').format(metrics.volume7d)} kg',
          metrics.prevVolume7d > 0 ? '${((metrics.volume7d - metrics.prevVolume7d)/metrics.prevVolume7d * 100).toStringAsFixed(0)}% vs last 7 days' : null,
          const Color(0xFF8B5CF6), // Purple
          Icons.bar_chart,
        ),
        _buildMetricCard(
          'Total Sets',
          '${metrics.totalSets}',
          metrics.prevTotalSets > 0 ? '${metrics.totalSets >= metrics.prevTotalSets ? '+' : ''}${metrics.totalSets - metrics.prevTotalSets} vs last 7 days' : null,
          AppTheme.accentAmber,
          Icons.layers,
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, String? subtext, Color iconColor, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bg850,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.bg800),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: iconColor.withOpacity(0.2), shape: BoxShape.circle),
                child: Icon(icon, size: 14, color: iconColor),
              ),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.text100)),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.text50)),
          if (subtext != null) ...[
            const SizedBox(height: 4),
            Text(subtext, style: TextStyle(fontSize: 10, color: subtext.startsWith('-') ? AppTheme.accentRed : AppTheme.accentGreen)),
          ]
        ],
      ),
    );
  }

  Widget _buildVolumeChart(AnalyticsProcessor processor) {
    final data = processor.getVolumeTrend(_selectedRange, lift: _selectedLift);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bg850,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.bg800),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Text('Weekly Volume ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.text50)),
                  Text('(kg)', style: TextStyle(fontSize: 14, color: AppTheme.text400)),
                  SizedBox(width: 4),
                  Icon(Icons.info_outline, size: 12, color: AppTheme.text500),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.bg900,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: const [
                    Text('Volume (kg)', style: TextStyle(fontSize: 11, color: AppTheme.text400)),
                    SizedBox(width: 4),
                    Icon(Icons.keyboard_arrow_down, size: 14, color: AppTheme.text400),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          VolumeChart(data: data),
        ],
      ),
    );
  }

  Widget _buildTopLifts(AnalyticsProcessor processor) {
    final variations = processor.getTopVariations(_selectedLift, _selectedRange);
    if (variations.isEmpty) return const SizedBox();

    final maxW = variations.first['weight'] as double;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bg850,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.bg800),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Top Lifts', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.text50)),
              Row(
                children: const [
                  Text('View All', style: TextStyle(fontSize: 12, color: AppTheme.accentBlue, fontWeight: FontWeight.w500)),
                  SizedBox(width: 4),
                  Icon(Icons.chevron_right, size: 14, color: AppTheme.accentBlue),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...variations.asMap().entries.take(4).map((e) {
            final idx = e.key;
            final item = e.value;
            final w = item['weight'] as double;
            final pct = w / maxW;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(color: AppTheme.bg800, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text('${idx + 1}', style: const TextStyle(fontSize: 11, color: AppTheme.text200, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(item['name'] as String, style: const TextStyle(fontSize: 13, color: AppTheme.text200)),
                            Text('${w.toStringAsFixed(0)} kg', style: const TextStyle(fontSize: 13, color: AppTheme.text300, fontFamily: 'monospace')),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
                          height: 4,
                          width: double.infinity,
                          decoration: BoxDecoration(color: AppTheme.bg900, borderRadius: BorderRadius.circular(2)),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: pct,
                            child: Container(
                              decoration: BoxDecoration(color: AppTheme.accentBlue, borderRadius: BorderRadius.circular(2)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildInsights(AnalyticsProcessor processor) {
    final insights = processor.getInsights(_selectedRange, lift: _selectedLift);
    if (insights.isEmpty) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bg850,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.bg800),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Text('Insights', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.text50)),
              SizedBox(width: 6),
              Icon(Icons.info_outline, size: 12, color: AppTheme.text500),
            ],
          ),
          const SizedBox(height: 16),
          ...insights.map((insight) {
            Color color;
            IconData icon;
            switch (insight.type) {
              case InsightType.positive:
                color = AppTheme.accentGreen;
                icon = Icons.trending_up;
                break;
              case InsightType.warning:
                color = AppTheme.accentAmber;
                icon = Icons.warning_amber_rounded;
                break;
              case InsightType.neutral:
                color = AppTheme.text500;
                icon = Icons.info_outline;
                break;
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
                    child: Icon(icon, size: 16, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(insight.text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
                        if (insight.subtext != null) ...[
                          const SizedBox(height: 4),
                          Text(insight.subtext!, style: const TextStyle(fontSize: 12, color: AppTheme.text300)),
                        ]
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 16, color: AppTheme.text500),
                ],
              ),
            );
          }).toList(),
        ],
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
