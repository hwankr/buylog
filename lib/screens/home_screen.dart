import 'package:flutter/material.dart';
import '../models/item.dart';
import '../services/item_store.dart';
import '../theme/app_theme.dart';
import '../widgets/item_card.dart';
import 'item_detail_screen.dart';
import 'add_item_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<ConsumableItem>>(
      valueListenable: ItemStore.instance,
      builder: (context, items, _) {
        final upcoming = List.of(items)
          ..sort((a, b) => a.daysRemaining.compareTo(b.daysRemaining));

        // 최근 구매: 전체 아이템, 가장 최근 구매일 기준 내림차순
        // 구매 이력이 없는 경우 등록 시각(id=타임스탬프) 기준
        DateTime latestDate(ConsumableItem item) {
          if (item.purchaseHistory.isNotEmpty) return item.purchaseHistory.first.date;
          final ts = int.tryParse(item.id);
          return ts != null ? DateTime.fromMillisecondsSinceEpoch(ts) : DateTime(2000);
        }
        final recentItems = List.of(items)
          ..sort((a, b) => latestDate(b).compareTo(latestDate(a)));

        return SafeArea(
          child: CustomScrollView(
            slivers: [
              // 헤더
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '안녕하세요, 민수님',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '오늘도 스마트한 소비 관리를 시작해볼까요?',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),

              // 교체 임박
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '교체 임박',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        '${upcoming.where((i) => i.daysRemaining <= 14).length}개',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (upcoming.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: _EmptySection(
                      icon: Icons.inventory_2_outlined,
                      message: '등록된 제품이 없습니다.\n+ 버튼으로 제품을 추가해보세요!',
                    ),
                  ),
                )
              else
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 185,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: upcoming.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final item = upcoming[index];
                        return ItemCard(
                          item: item,
                          onTap: () => _openDetail(context, item),
                        );
                      },
                    ),
                  ),
                ),

              // 최근 구매
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '최근 구매',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (items.isNotEmpty)
                        TextButton(
                          onPressed: () => _openAddItem(context),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            '+ 추가',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              if (recentItems.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: _EmptySection(
                      icon: Icons.receipt_long_outlined,
                      message: '등록된 제품이 없습니다.',
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList.separated(
                    itemCount: recentItems.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = recentItems[index];
                      return PurchaseListItem(
                        item: item,
                        onTap: () => _openDetail(context, item),
                      );
                    },
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        );
      },
    );
  }

  void _openDetail(BuildContext context, ConsumableItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ItemDetailScreen(item: item)),
    );
  }

  void _openAddItem(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddItemScreen()),
    );
  }
}

// 빈 상태 안내 위젯
class _EmptySection extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptySection({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(icon, size: 40, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textMuted,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
