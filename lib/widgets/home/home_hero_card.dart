import 'package:flutter/material.dart';
import '../../models/item.dart';
import '../../theme/app_theme.dart';
import '../countdown_ring.dart';

/// 홈 화면 최상단 히어로 카드 — 가장 시급한 교체 한 건을 강조.
///
/// 디자인 핸드오프 prototype.html `screens-a.jsx::HomeScreen`의 hero 카드 매핑.
/// 팀원 위젯(`widgets/item_card.dart`의 `ItemCard`/`PurchaseListItem`)과
/// 구조적으로 다르므로 별도 파일로 분리. 색은 모두 `AppColors` 토큰 경유.
class HomeHeroCard extends StatelessWidget {
  const HomeHeroCard({
    super.key,
    required this.item,
    required this.onTap,
    this.onDetailTap,
    this.onOrderTap,
  });

  final ConsumableItem item;

  /// 카드 본체(영역) 탭 시 호출. 일반적으로 상세 화면 진입.
  final VoidCallback onTap;

  /// "자세히" 버튼 전용 핸들러. null이면 [onTap]로 폴백.
  final VoidCallback? onDetailTap;

  /// "지금 주문" 핸들러. null이면 버튼 자체를 렌더링하지 않는다.
  final VoidCallback? onOrderTap;

  Color get _tierBg {
    if (item.daysRemaining <= 3) return AppColors.dangerLight;
    if (item.daysRemaining <= 7) return AppColors.warningLight;
    if (item.daysRemaining <= 14) return AppColors.primaryLight2;
    return AppColors.successLight;
  }

  static String _ymd(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final lastPurchase = item.purchaseHistory.isNotEmpty
        ? item.purchaseHistory.first.date
        : null;
    final aiPct = item.aiConfidence == null
        ? null
        : (item.aiConfidence!.clamp(0.0, 1.0) * 100).round();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              color: _tierBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.18),
                width: 0.5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '가장 시급한 교체',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CountdownRing(
                        daysRemaining: item.daysRemaining,
                        totalDays: item.cycleDays,
                        size: 84,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.text,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              lastPurchase == null
                                  ? item.brand
                                  : '${item.brand} · 마지막 구매 ${_ymd(lastPurchase)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (aiPct != null)
                              _MiniPill(
                                icon: Icons.auto_awesome,
                                label: 'AI 예측 $aiPct%',
                                fg: AppColors.textSecondary,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _HeroButton(
                          label: '자세히',
                          background: AppColors.surface,
                          foreground: AppColors.textSecondary,
                          border: AppColors.border,
                          onTap: onDetailTap ?? onTap,
                        ),
                      ),
                      if (onOrderTap != null) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: _HeroButton(
                            label: '지금 주문',
                            icon: Icons.storefront_outlined,
                            background: AppColors.success,
                            foreground: Colors.white,
                            onTap: onOrderTap!,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill({this.icon, required this.label, required this.fg});

  final IconData? icon;
  final String label;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: AppColors.primary),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fg,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroButton extends StatelessWidget {
  const _HeroButton({
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
    this.icon,
    this.border,
  });

  final String label;
  final IconData? icon;
  final Color background;
  final Color foreground;
  final Color? border;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(12),
            border: border == null
                ? null
                : Border.all(color: border!, width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: foreground),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: foreground,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
