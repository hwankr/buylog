import 'package:flutter/material.dart';

import '../../services/report_service.dart';
import '../../theme/app_theme.dart';
import 'report_palette.dart';

class ReportInsightStrip extends StatelessWidget {
  const ReportInsightStrip({super.key, required this.insights});

  final List<ReportInsight> insights;

  @override
  Widget build(BuildContext context) {
    if (insights.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width - 40;
        final cardWidth = availableWidth < 250 ? availableWidth : 250.0;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: [
              for (var i = 0; i < insights.length; i++) ...[
                SizedBox(
                  width: cardWidth,
                  child: _InsightCard(insight: insights[i]),
                ),
                if (i != insights.length - 1) const SizedBox(width: 10),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.insight});

  final ReportInsight insight;

  @override
  Widget build(BuildContext context) {
    final accent = ReportPalette.insightColor(insight.kind);
    final surface = ReportPalette.insightSurface(insight.kind);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accent.withValues(alpha: 0.22),
          width: 0.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_iconFor(insight.kind), size: 18, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  insight.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                    color: AppColors.text,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

IconData _iconFor(ReportInsightKind kind) {
  return switch (kind) {
    ReportInsightKind.spending => Icons.insights_outlined,
    ReportInsightKind.refill => Icons.event_repeat_outlined,
    ReportInsightKind.price => Icons.price_change_outlined,
  };
}
