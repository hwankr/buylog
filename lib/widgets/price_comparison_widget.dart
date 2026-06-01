import 'package:flutter/material.dart';
import '../models/item.dart';
import '../theme/app_theme.dart';

class PriceComparisonWidget extends StatelessWidget {
  final bool isLoadingPrice;
  final List<PriceComparison> realPriceData;
  final Function(int) onLinkTap;

  const PriceComparisonWidget({
    super.key,
    required this.isLoadingPrice,
    required this.realPriceData,
    required this.onLinkTap,
  });

  @override
  Widget build(BuildContext context) {
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
          const Row(
            children: [
              Icon(
                Icons.auto_awesome_outlined,
                size: 18,
                color: AppColors.primary,
              ),
              SizedBox(width: 8),
              Text(
                'AI 가격 비교',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isLoadingPrice)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: CircularProgressIndicator(),
              ),
            )
          else if (realPriceData.isEmpty)
            const Text(
              '최저가 정보를 불러올 수 없습니다.',
              style: TextStyle(color: AppColors.textMuted),
            )
          else
            ...realPriceData.asMap().entries.map(
              (entry) {
                final int index = entry.key;
                final p = entry.value;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    onTap: () => onLinkTap(index),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 4,
                      ),
                      child: Row(
                        children: [
                          if (p.isLowest)
                            const Icon(
                              Icons.check_circle,
                              size: 16,
                              color: AppColors.success,
                            )
                          else
                            const SizedBox(width: 16),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              p.store,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: p.isLowest
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: p.isLowest
                                    ? AppColors.text
                                    : AppColors.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${p.price}원',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: p.isLowest
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: p.isLowest
                                  ? AppColors.success
                                  : AppColors.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}