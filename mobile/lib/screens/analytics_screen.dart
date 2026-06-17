import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';
import '../services/analytics_processor.dart';
import '../theme/app_colors.dart';
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
      backgroundColor: AppColors.bg,
      appBar: canPop ? AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ) : null,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppColors.accentBlue,
          backgroundColor: AppColors.cardBg,
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
                  child: Center(child: CircularProgressIndicator(color: AppColors.accentBlue, strokeWidth: 2)),
                )
              else if (_sessions.isEmpty)
                _buildEmptyState()
              else ...[
                _buildSessionRatings(),
                const SizedBox(height: 16),
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
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.borderColor),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<TimeRange>(
              value: _selectedRange,
              dropdownColor: AppColors.cardBg,
              icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary, size: 16),
              isDense: true,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
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
                        const Icon(Icons.calendar_today, size: 12, color: AppColors.textMuted),
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
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
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
                  color: isSelected ? AppColors.accentBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(lift['icon'] as IconData, size: 16, color: isSelected ? Colors.white : AppColors.textMuted),
                    const SizedBox(width: 8),
                    Text(
                      lift['name'] as String,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        color: isSelected ? Colors.white : AppColors.textSecondary,
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

  // ─── Session Ratings Card ───
  Widget _buildSessionRatings() {
    final ratedSessions = _sessions
        .where((s) => s['sessionRating'] != null)
        .toList();

    ratedSessions.sort((a, b) {
      final da = DateTime.tryParse(a['date']?.toString() ?? '') ?? DateTime(2000);
      final db = DateTime.tryParse(b['date']?.toString() ?? '') ?? DateTime(2000);
      return da.compareTo(db);
    });

    final recent = ratedSessions.length > 10
        ? ratedSessions.sublist(ratedSessions.length - 10)
        : ratedSessions;

    double avgRating = 0;
    if (recent.isNotEmpty) {
      avgRating = recent.map((s) => (s['sessionRating'] as num).toDouble()).reduce((a, b) => a + b) / recent.length;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: AppColors.accentBlueBg,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.star_rounded, size: 16, color: AppColors.accentBlueLight),
                  ),
                  const SizedBox(width: 10),
                  const Text('SESSION RATINGS', style: TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                ],
              ),
              if (recent.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _ratingBgColor(avgRating),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.trending_up, size: 12, color: _ratingFgColor(avgRating)),
                      const SizedBox(width: 4),
                      Text(
                        'Avg ${avgRating.toStringAsFixed(1)}',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _ratingFgColor(avgRating)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),

          if (recent.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'No ratings yet. Rate your next session!',
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
              ),
            )
          else ...[
            SizedBox(
              height: 120,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: recent.asMap().entries.map((entry) {
                  final index = entry.key;
                  final session = entry.value;
                  final rating = (session['sessionRating'] as num).toInt();
                  final date = DateTime.tryParse(session['date']?.toString() ?? '');
                  final dateLabel = date != null ? DateFormat('d/M').format(date) : '';
                  final barHeight = (rating / 10) * 90.0;

                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: index == 0 ? 0 : 4,
                        right: index == recent.length - 1 ? 0 : 4,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '$rating',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _ratingDotColor(rating),
                            ),
                          ),
                          const SizedBox(height: 4),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeOutBack,
                            height: barHeight,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  _ratingDotColor(rating).withOpacity(0.3),
                                  _ratingDotColor(rating),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            dateLabel,
                            style: const TextStyle(fontSize: 9, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            Container(height: 1, color: AppColors.borderColor),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildRatingStat('Best', recent.map((s) => (s['sessionRating'] as num).toInt()).reduce((a, b) => a > b ? a : b).toString(), AppColors.accentGreen),
                _buildRatingStat('Average', avgRating.toStringAsFixed(1), AppColors.accentBlueLight),
                _buildRatingStat('Sessions', '${recent.length}', AppColors.textSecondary),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRatingStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color, fontFamily: 'monospace')),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Color _ratingDotColor(int rating) {
    if (rating <= 3) return const Color(0xFFEF4444);
    if (rating <= 5) return const Color(0xFFF97316);
    if (rating <= 7) return const Color(0xFFEAB308);
    if (rating <= 9) return const Color(0xFF22C55E);
    return const Color(0xFF10B981);
  }

  Color _ratingBgColor(double rating) {
    if (rating <= 3) return const Color(0xFF2D1818);
    if (rating <= 5) return const Color(0xFF2D2218);
    if (rating <= 7) return const Color(0xFF2D2A18);
    return const Color(0xFF182D1E);
  }

  Color _ratingFgColor(double rating) {
    if (rating <= 3) return const Color(0xFFEF4444);
    if (rating <= 5) return const Color(0xFFF97316);
    if (rating <= 7) return const Color(0xFFEAB308);
    return const Color(0xFF22C55E);
  }

  Widget _buildStrengthChart(AnalyticsProcessor processor) {
    final data = processor.getStrengthTrend(_selectedLift, _selectedRange);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Strength Progress (Top Set)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.inputBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  children: [
                    Text('1RM Trend', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    SizedBox(width: 4),
                    Icon(Icons.keyboard_arrow_down, size: 14, color: AppColors.textSecondary),
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
          null,
          AppColors.accentBlue,
          Icons.emoji_events,
        ),
        _buildMetricCard(
          'Est. 1RM',
          '${metrics.est1RM.toStringAsFixed(0)} kg',
          metrics.prevEst1RM > 0 ? '${metrics.est1RM >= metrics.prevEst1RM ? '+' : ''}${(metrics.est1RM - metrics.prevEst1RM).toStringAsFixed(0)} kg vs last period' : null,
          AppColors.accentGreen,
          Icons.trending_up,
        ),
        _buildMetricCard(
          'Volume (7d)',
          '${NumberFormat('#,##0').format(metrics.volume7d)} kg',
          metrics.prevVolume7d > 0 ? '${((metrics.volume7d - metrics.prevVolume7d)/metrics.prevVolume7d * 100).toStringAsFixed(0)}% vs last 7 days' : null,
          const Color(0xFF8B5CF6),
          Icons.bar_chart,
        ),
        _buildMetricCard(
          'Total Sets',
          '${metrics.totalSets}',
          metrics.prevTotalSets > 0 ? '${metrics.totalSets >= metrics.prevTotalSets ? '+' : ''}${metrics.totalSets - metrics.prevTotalSets} vs last 7 days' : null,
          const Color(0xFFEAB308),
          Icons.layers,
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, String? subtext, Color iconColor, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor),
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
              Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          if (subtext != null) ...[
            const SizedBox(height: 4),
            Text(subtext, style: TextStyle(fontSize: 10, color: subtext.startsWith('-') ? AppColors.accentRed : AppColors.accentGreen)),
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
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Text('Weekly Volume ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  Text('(kg)', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                  SizedBox(width: 4),
                  Icon(Icons.info_outline, size: 12, color: AppColors.textMuted),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.inputBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  children: [
                    Text('Volume (kg)', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    SizedBox(width: 4),
                    Icon(Icons.keyboard_arrow_down, size: 14, color: AppColors.textSecondary),
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
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Top Lifts', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              Row(
                children: [
                  Text('View All', style: TextStyle(fontSize: 12, color: AppColors.accentBlueLight, fontWeight: FontWeight.w500)),
                  SizedBox(width: 4),
                  Icon(Icons.chevron_right, size: 14, color: AppColors.accentBlueLight),
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
                    decoration: const BoxDecoration(color: AppColors.inputBg, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text('${idx + 1}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(item['name'] as String, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                            Text('${w.toStringAsFixed(0)} kg', style: const TextStyle(fontSize: 13, color: AppColors.textMuted, fontFamily: 'monospace')),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
                          height: 4,
                          width: double.infinity,
                          decoration: BoxDecoration(color: AppColors.inputBg, borderRadius: BorderRadius.circular(2)),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: pct,
                            child: Container(
                              decoration: BoxDecoration(color: AppColors.accentBlue, borderRadius: BorderRadius.circular(2)),
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
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('Insights', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              SizedBox(width: 6),
              Icon(Icons.info_outline, size: 12, color: AppColors.textMuted),
            ],
          ),
          const SizedBox(height: 16),
          ...insights.map((insight) {
            Color color;
            IconData icon;
            switch (insight.type) {
              case InsightType.positive:
                color = AppColors.accentGreen;
                icon = Icons.trending_up;
                break;
              case InsightType.warning:
                color = const Color(0xFFEAB308);
                icon = Icons.warning_amber_rounded;
                break;
              case InsightType.neutral:
                color = AppColors.textMuted;
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
                          Text(insight.subtext!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ]
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 16, color: AppColors.textMuted),
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
          Icon(Icons.analytics_outlined, size: 48, color: AppColors.textMuted),
          const SizedBox(height: 16),
          const Text(
            'No sessions logged yet',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          const Text(
            'Start training to see your analytics',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
