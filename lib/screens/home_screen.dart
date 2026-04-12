import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // [Issue 4] Supabase 연동을 위한 임포트
import '../theme/app_theme.dart';
import '../widgets/item_card.dart';
import '../models/item.dart'; // [Issue 4] DB 데이터를 담을 모델 클래스 임포트
import 'item_detail_screen.dart';
import '../data/sample_data.dart';

// [Issue 4] 실시간 데이터 반영 및 상태 관리를 위해 StatefulWidget으로 전환
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // [Issue 4] Supabase 클라이언트 및 로컬 상태 변수 선언
  final _supabase = Supabase.instance.client;
  List<ConsumableItem> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // [Issue 4] 샘플 데이터 대신 실제 DB 데이터를 가져오도록 수정
    _fetchDbData(); 
  }

  // [Issue 4] Supabase에서 product_items와 purchases를 Join하여 가져오는 핵심 함수
  Future<void> _fetchDbData() async {
    // 데이터를 새로 불러올 때 로딩 상태를 확실히 하기 위해 true로 설정 (최적화)
    if (!_isLoading) setState(() => _isLoading = true);

    try {
      final response = await _supabase
          .from('product_items')
          .select('*, purchases(*)') // [Issue 4] 릴레이션 조인으로 하위 구매이력 동시 조회
          .order('created_at', ascending: false);

      final List<dynamic> data = response;
      
      setState(() {
        // [Issue 4] 모델 클래스의 팩토리 메서드를 사용하여 JSON -> 객체 변환
        _items = data.map((json) => ConsumableItem.fromJson(json)).toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('데이터 로딩 에러: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final upcoming = List.of(_items)
      ..sort((a, b) => a.daysRemaining.compareTo(b.daysRemaining));

    return SafeArea(
      // [Issue 4] 데이터 로딩 상태에 따른 조건부 렌더링 (로딩 인디케이터 표시)
      child: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '안녕하세요, 재현님',
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

              // Upcoming Replacements
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
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 185,
                  // [Issue 4] DB 데이터 유무에 따른 예외 처리
                  child: upcoming.isEmpty 
                    ? const Center(child: Text('등록된 아이템이 없습니다.'))
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: upcoming.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final item = upcoming[index];
                          return ItemCard(
                            item: item,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ItemDetailScreen(item: item),
                              ),
                            ),
                          );
                        },
                      ),
                ),
              ),

              // Recent Purchases
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
                  child: Text(
                    '최근 구매',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ),
              // [Issue 4] 구매 내역 필터링 및 리스트 렌더링
              _items.isEmpty 
                ? const SliverToBoxAdapter(child: Center(child: Text('최근 구매 내역이 없습니다.')))
                : SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList.separated(
                      itemCount: _items.where((i) => i.purchaseHistory.isNotEmpty).length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final purchasedItems =
                            _items.where((i) => i.purchaseHistory.isNotEmpty).toList();
                        final item = purchasedItems[index];
                        return PurchaseListItem(
                          item: item,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ItemDetailScreen(item: item),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
    );
  }
}