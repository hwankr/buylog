import 'package:flutter/material.dart';
import '../main.dart';
import '../models/item.dart';
import '../services/item_store.dart';
import '../services/recent_purchase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/home/home_hero_card.dart';
import '../widgets/home/upcoming_item_row.dart';
import 'item_detail_screen.dart';
import 'items_screen.dart';

/// 홈 — 큐레이팅 다이제스트.
///
/// 인사말 → 히어로 카드(가장 시급) → AI 인사이트 → 다가오는 교체 4건 →
/// 최근 기록. 전체 품목 목록은 `모든 제품` 탭이 담당.
///
/// 데이터는 `ItemStore` 단일 소스 구독. `AddItemScreen`/`ItemDetailScreen`
/// 의 add/update/delete가 이 화면에 즉시 반영된다.
///
/// 디자인/의사결정 사유: `docs/REDESIGN_NOTES.md`
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _userName = '사용자';

  void _goToItemsTab() {
    final root = context.findAncestorStateOfType<MainNavigationState>();
    if (root != null) {
      root.switchTab(MainNavigationState.kItemsTabIndex);
    } else {
      // 위젯 테스트나 MainNavigation 외부 컨텍스트 폴백.
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ItemsScreen(showBack: true)),
      );
    }
  }

  void _openDetail(ConsumableItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ItemDetailScreen(item: item)),
    );
  }

  String _formattedDate() {
    const weekdays = ['월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일'];
    final now = DateTime.now();
    final wd = weekdays[(now.weekday - 1).clamp(0, 6)];
    return '${now.year}년 ${now.month}월 ${now.day}일 $wd';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ValueListenableBuilder<List<ConsumableItem>>(
        valueListenable: ItemStore.instance,
        builder: (context, items, _) {
          if (items.isEmpty) {
            return _EmptyHome(onAdd: _goToItemsTab, userName: _userName);
          }

          final sorted = List.of(items)
            ..sort((a, b) => a.daysRemaining.compareTo(b.daysRemaining));
          final hero = sorted.first;
          final upcoming = sorted.skip(1).take(4).toList();
          final weekCount = items.where((i) => i.daysRemaining <= 7).length;
          final recentRows = RecentPurchaseService.fromItems(items);

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _Greeting(
                  date: _formattedDate(),
                  name: _userName,
                  weekCount: weekCount,
                ),
              ),
              SliverToBoxAdapter(
                child: HomeHeroCard(item: hero, onTap: () => _openDetail(hero)),
              ),
              const SliverToBoxAdapter(child: _AiInsightCard()),
              if (upcoming.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: _SectionHeader(
                    title: '다가오는 교체',
                    trailing: TextButton(
                      onPressed: _goToItemsTab,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '모두 보기',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 2),
                          Icon(Icons.chevron_right, size: 14),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  sliver: SliverList.separated(
                    itemCount: upcoming.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) => UpcomingItemRow(
                      item: upcoming[index],
                      onTap: () => _openDetail(upcoming[index]),
                    ),
                  ),
                ),
              ],
              const SliverToBoxAdapter(child: _SectionHeader(title: '최근 기록')),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
                sliver: SliverToBoxAdapter(
                  child: recentRows.isEmpty
                      ? const _RecentEmptyState()
                      : Column(
                          children: [
                            for (final row in recentRows)
                              _LedgerRow(
                                time: _formatRecentDate(row.date),
                                text: _formatRecentText(row),
                              ),
                          ],
                        ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 28)),
            ],
          );
        },
      ),
    );
  }

  String _formatRecentDate(DateTime date) {
    final today = DateTime.now();
    if (date.year == today.year &&
        date.month == today.month &&
        date.day == today.day) {
      return '오늘';
    }

    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$month.$day';
  }

  String _formatRecentText(RecentPurchaseRecord record) {
    final store = record.store.trim().isEmpty ? '구매처 미입력' : record.store;
    return '${record.itemName} 구매 기록됨 · $store · ${_formatPrice(record.price)}';
  }

  String _formatPrice(int price) {
    final digits = price.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(digits[i]);
    }
    return '$buffer원';
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({
    required this.date,
    required this.name,
    required this.weekCount,
  });

  final String date;
  final String name;
  final int weekCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            date,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 4),
          Text(
            '안녕하세요, $name님',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
              letterSpacing: -0.7,
            ),
          ),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              children: [
                const TextSpan(text: '이번 주 교체 예정인 소모품 '),
                TextSpan(
                  text: '$weekCount개',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const TextSpan(text: '가 있어요'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AiInsightCard extends StatelessWidget {
  const _AiInsightCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.successLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.success.withValues(alpha: 0.18),
            width: 0.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.success,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.auto_awesome,
                size: 14,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI 인사이트',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                      letterSpacing: -0.1,
                    ),
                  ),
                  SizedBox(height: 3),
                  // TODO: 디자인 프로토타입 mock 카피. 실제 AI 인사이트
                  // 데이터 소스 연결 시 교체.
                  Text(
                    '평균 90일 주기지만 최근엔 85일에 교체하셨어요. 4개월 전보다 사용량이 6% 늘었어요.',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
                letterSpacing: -0.4,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({required this.time, required this.text});

  final String time;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              time,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.text,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentEmptyState extends StatelessWidget {
  const _RecentEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          '최근 기록이 없습니다.',
          style: TextStyle(
            fontSize: 13,
            height: 1.5,
            color: AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _EmptyHome extends StatelessWidget {
  const _EmptyHome({required this.onAdd, required this.userName});

  final VoidCallback onAdd;
  final String userName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
            child: Text(
              '안녕하세요, $userName님',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
                letterSpacing: -0.6,
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '아직 등록된 아이템이 없어요',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: onAdd,
            child: Container(
              padding: const EdgeInsets.all(28),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border, width: 1),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 38,
                    color: AppColors.textMuted,
                  ),
                  SizedBox(height: 12),
                  Text(
                    '영수증 한 장으로 시작하세요',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '하단 + 버튼으로 카메라 스캔이나 직접 등록을 시작할 수 있어요',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
