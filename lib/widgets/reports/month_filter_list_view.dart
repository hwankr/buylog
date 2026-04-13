import 'package:flutter/material.dart';

import '../../models/item.dart';
import '../../services/report_service.dart';
import '../../theme/app_theme.dart';
import 'category_pie_chart.dart';

class MonthFilterListView extends StatelessWidget {
  const MonthFilterListView({
    super.key,
    required this.selectedMonth,
    required this.service,
  });

  final DateTime? selectedMonth;
  final ReportService service;

  // TODO: 4번째 중복. 후속 이슈에서 lib/utils/price_format.dart 등으로 통합.
  //   기존: reports_screen.dart:14, item_detail_screen.dart:12, item_card.dart:92.
  String _formatPrice(int price) {
    final str = price.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write(',');
      buffer.write(str[i]);
    }
    return '${buffer}원';
  }

  @override
  Widget build(BuildContext context) {
    final month = selectedMonth;
    if (month == null) return const SizedBox.shrink();

    final items = service.itemsOfMonth(month);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${month.month}월 상세 내역',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            _emptyCard()
          else
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _itemCard(item, month),
              ),
            ),
        ],
      ),
    );
  }

  Widget _emptyCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: const Text(
        '해당 월에 기록된 구매가 없어요',
        style: TextStyle(fontSize: 13, color: AppColors.textMuted),
      ),
    );
  }

  Widget _itemCard(ConsumableItem item, DateTime month) {
    final color = colorForCategory(item.category);
    final monthlyPurchases = item.purchaseHistory
        .where((p) => p.date.year == month.year && p.date.month == month.month)
        .toList();
    final totalForMonth = monthlyPurchases.fold<int>(
      0,
      (sum, p) => sum + p.price,
    );
    final latestPurchaseDate = monthlyPurchases.isEmpty
        ? null
        : monthlyPurchases
              .map((p) => p.date)
              .reduce((a, b) => a.isAfter(b) ? a : b);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item.icon, color: color, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.brand,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatPrice(totalForMonth),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              if (latestPurchaseDate != null)
                Text(
                  '${latestPurchaseDate.month}/${latestPurchaseDate.day}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
