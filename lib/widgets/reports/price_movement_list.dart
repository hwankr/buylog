import 'package:flutter/material.dart';

import '../../services/report_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/price_format.dart';
import 'report_palette.dart';

class PriceMovementList extends StatelessWidget {
  const PriceMovementList({super.key, required this.movements});

  final List<PriceMovement> movements;

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
          Text('가격 변동', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          if (movements.isEmpty)
            const Text(
              '비교할 최근 가격 변동이 없어요',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            )
          else
            ...movements.map((movement) => _MovementRow(movement: movement)),
        ],
      ),
    );
  }
}

class _MovementRow extends StatelessWidget {
  const _MovementRow({required this.movement});

  final PriceMovement movement;

  @override
  Widget build(BuildContext context) {
    final deltaColor = movement.deltaAmount > 0
        ? AppColors.danger
        : AppColors.success;
    final deltaLabel = movement.deltaAmount > 0 ? '상승' : '하락';
    final categoryColor = colorForCategory(movement.item.category);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: categoryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(movement.item.icon, size: 18, color: categoryColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  movement.item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                Text(
                  '${movement.previousStore} → ${movement.currentStore}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatPrice(movement.currentPrice),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
              Text(
                '${formatPrice(movement.deltaAmount.abs())} $deltaLabel',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: deltaColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
