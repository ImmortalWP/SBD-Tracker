import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/analytics_processor.dart';

class InsightsWidget extends StatelessWidget {
  final List<Insight> insights;

  const InsightsWidget({super.key, required this.insights});

  @override
  Widget build(BuildContext context) {
    if (insights.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: insights.map((insight) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 2),
                child: Icon(
                  _iconFor(insight.type),
                  size: 14,
                  color: _colorFor(insight.type),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  insight.text,
                  style: TextStyle(
                    fontSize: 13,
                    color: _colorFor(insight.type).withValues(alpha: 0.9),
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  IconData _iconFor(InsightType type) {
    switch (type) {
      case InsightType.positive:
        return Icons.trending_up;
      case InsightType.warning:
        return Icons.warning_amber_rounded;
      case InsightType.neutral:
        return Icons.info_outline;
    }
  }

  Color _colorFor(InsightType type) {
    switch (type) {
      case InsightType.positive:
        return AppTheme.accentGreen;
      case InsightType.warning:
        return AppTheme.accentAmber;
      case InsightType.neutral:
        return AppTheme.text500;
    }
  }
}
