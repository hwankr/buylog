import 'package:flutter/material.dart';

import '../../services/report_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/price_format.dart';
import 'report_palette.dart';

class RefillForecastCard extends StatelessWidget {
  const RefillForecastCard({super.key, required this.forecast});

  final RefillForecast forecast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('다가오는 재구매', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _WindowAmount(
                  label: '30일',
                  amount: forecast.next30DaysAmount,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _WindowAmount(
                  label: '60일',
                  amount: forecast.next60DaysAmount,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _WindowAmount(
                  label: '90일',
                  amount: forecast.next90DaysAmount,
                ),
              ),
            ],
          ),
          if (forecast.items.isEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              '90일 안에 예정된 재구매가 없어요',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ] else ...[
            const SizedBox(height: 14),
            ...forecast.items
                .take(3)
                .map((entry) => _ForecastRow(entry: entry)),
          ],
        ],
      ),
    );
  }
}

class _WindowAmount extends StatelessWidget {
  const _WindowAmount({required this.label, required this.amount});

  final String label;
  final int amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatPrice(amount),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ForecastRow extends StatelessWidget {
  const _ForecastRow({required this.entry});

  final RefillForecastItem entry;

  @override
  Widget build(BuildContext context) {
    final color = colorForCategory(entry.item.category);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(entry.item.icon, size: 17, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                Text(
                  '${entry.daysUntilRefill}일 후',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Text(
            formatPrice(entry.expectedPrice),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}
