import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../widgets/item_card.dart';
import '../models/item.dart';
import 'item_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _supabase = Supabase.instance.client;

  // 인피니티 스크롤 전용 컨트롤 및 변수
  final ScrollController _scrollController = ScrollController();
  List<ConsumableItem> _items = [];
  bool _isLoading = true; // 첫 로딩 상태
  bool _isMoreLoading = false; // 추가 페이지 로딩 상태
  bool _hasNextPage = true; // 더 가져올 데이터가 있는지 여부
  int _currentPage = 0; // 현재 페이지 번호
  final int _pageSize = 10; // 한 번에 가져올 아이템 수

  @override
  void initState() {
    super.initState();
    _fetchDbData(isInitial: true);

    // 스크롤 리스너 등록: 사용자가 끝까지 내렸는지 확인
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent * 0.9 &&
          !_isMoreLoading &&
          _hasNextPage) {
        _fetchDbData(); // 다음 페이지 호출
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose(); // 메모리 누수 방지
    super.dispose();
  }

  // Supabase 페이지네이션 쿼리 함수
  Future<void> _fetchDbData({bool isInitial = false}) async {
    if (isInitial) {
      setState(() {
        _isLoading = true;
        _currentPage = 0;
        _hasNextPage = true;
        _items = [];
      });
    } else {
      setState(() => _isMoreLoading = true);
    }

    try {
      // 시작 지점(from)과 끝 지점(to) 계산
      final from = _currentPage * _pageSize;
      final to = from + _pageSize - 1;

      final response = await _supabase
          .from('product_items')
          .select('*, purchases(*)')
          .order('created_at', ascending: false)
          .range(from, to);

      final List<dynamic> data = response;
      final newItems = data
          .map((json) => ConsumableItem.fromJson(json))
          .toList();

      setState(() {
        _items.addAll(newItems);
        _isLoading = false;
        _isMoreLoading = false;

        // 가져온 데이터가 요청한 개수보다 적으면 '마지막 페이지'로 간주
        if (newItems.length < _pageSize) {
          _hasNextPage = false;
        } else {
          _currentPage++;
        }
      });
    } catch (e) {
      debugPrint('데이터 로딩 에러: $e');
      setState(() {
        _isLoading = false;
        _isMoreLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // D-Day 순 정렬
    final upcoming = List.of(_items)
      ..sort((a, b) => a.daysRemaining.compareTo(b.daysRemaining));

    return SafeArea(
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              controller: _scrollController, // 컨트롤러 연결
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '안녕하세요, 사용자님',
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
                    child: upcoming.isEmpty
                        ? const Center(child: Text('등록된 아이템이 없습니다.'))
                        : ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: upcoming.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 12),
                            itemBuilder: (context, index) => ItemCard(
                              item: upcoming[index],
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ItemDetailScreen(item: upcoming[index]),
                                ),
                              ),
                            ),
                          ),
                  ),
                ),

                // 최근 구매 리스트 영역
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
                    child: Text(
                      '전체 품목 리스트',
                      style: Theme.of(context).textTheme.titleLarge,
                    ), // 인피니트 스크롤 확인을 위해 전체 리스트로 표시
                  ),
                ),

                _items.isEmpty
                    ? const SliverToBoxAdapter(
                        child: Center(child: Text('내역이 없습니다.')),
                      )
                    : SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        sliver: SliverList.separated(
                          itemCount: _items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            return PurchaseListItem(
                              // 리스트 형태의 아이템 위젯
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

                // 스크롤 하단 로딩 인디케이터
                if (_isMoreLoading)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),

                // 마지막 여백
                const SliverToBoxAdapter(child: SizedBox(height: 50)),
              ],
            ),
    );
  }
}
