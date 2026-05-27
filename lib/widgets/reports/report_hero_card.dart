import 'package:flutter/material.dart';

import '../../services/report_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/price_format.dart';

class ReportHeroCard extends StatelessWidget {
  const ReportHeroCard({super.key, required this.title, required this.summary});

  final String title;
  final ReportPeriodSummary summary;

  @override
  Widget build(BuildContext context) {
    final deltaLabel = summary.deltaAmount == 0
        ? '전 기간과 동일'
        : '전 기간 대비 ${formatPrice(summary.deltaAmount.abs())} ${summary.deltaAmount > 0 ? '증가' : '감소'}';
    final topCategoryLabel = summary.topCategory == null
        ? '카테고리 없음'
        : '${summary.topCategory} ${formatPrice(summary.topCategoryAmount)}';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            formatPrice(summary.totalAmount),
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetricChip(
                icon: summary.deltaAmount > 0
                    ? Icons.trending_up_outlined
                    : Icons.trending_down_outlined,
                label: deltaLabel,
              ),
              _MetricChip(
                icon: Icons.receipt_long_outlined,
                label: '구매 ${summary.purchaseCount}건',
              ),
              _MetricChip(
                icon: Icons.category_outlined,
                label: topCategoryLabel,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.primary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
