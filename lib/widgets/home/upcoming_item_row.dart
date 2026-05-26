import 'package:flutter/material.dart';
import '../../models/item.dart';
import '../../theme/app_theme.dart';
import '../dday_badge.dart';

/// 홈 "다가오는 교체" 섹션의 컴팩트 행 (40 px 아이콘 타일 + 이름·메타 + D-day 배지).
///
/// `widgets/item_card.dart::PurchaseListItem`과 비슷하지만 D-day 강조 + 더
/// 컴팩트한 패딩이라 별도 위젯으로 둔다. 팀원 코드를 수정하지 않기 위함.
class UpcomingItemRow extends StatelessWidget {
  const UpcomingItemRow({super.key, required this.item, required this.onTap});

  final ConsumableItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cyclePart = item.aiPredictedDays ?? item.cycleDays;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  item.icon,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.brand} · 주기 $cyclePart일',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              DdayBadge(daysRemaining: item.daysRemaining),
            ],
          ),
        ),
      ),
    );
  }
}
