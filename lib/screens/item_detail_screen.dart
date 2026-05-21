import 'package:flutter/material.dart';
import '../data/sample_data.dart';
import '../models/item.dart';
import '../services/item_store.dart';
import '../theme/app_theme.dart';
import '../widgets/countdown_ring.dart';
import 'add_item_screen.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ItemDetailScreen extends StatefulWidget {
  final ConsumableItem item;

  const ItemDetailScreen({super.key, required this.item});

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  late ConsumableItem _item;

  // 실시간 가격 데이터 변수
  bool _isLoadingPrice = true;
  List<PriceComparison> _realPriceData = [];
  String? _buyLink; // 구매 링크 저장용

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    ItemStore.instance.addListener(_onStoreChanged);

    _fetchRealTimePrice();
  }

  Future<void> _fetchRealTimePrice() async {
    final String naverId = dotenv.env['NAVER_CLIENT_ID'] ?? '';
    final String naverSecret = dotenv.env['NAVER_CLIENT_SECRET'] ?? '';
    final String openaiKey = dotenv.env['OPENAI_API_KEY'] ?? '';

    if (naverId.isEmpty || naverSecret.isEmpty || openaiKey.isEmpty) {
      debugPrint('API 키가 설정되지 않았습니다.');
      if (mounted) setState(() => _isLoadingPrice = false);
      return;
    }

    // 네이버 쇼핑 검색 API 호출
    final String searchQuery = '${_item.brand} ${_item.name}'.trim();
    final naverUrl = 'https://openapi.naver.com/v1/search/shop.json?query=${Uri.encodeComponent(searchQuery)}&display=1';
    
    try {
      final naverResponse = await http.get(
        Uri.parse(naverUrl),
        headers: {
          'X-Naver-Client-Id': naverId,
          'X-Naver-Client-Secret': naverSecret,
        },
      );

      if (naverResponse.statusCode == 200) {
        final naverData = jsonDecode(utf8.decode(naverResponse.bodyBytes));
        final items = naverData['items'] as List;

        if (items.isNotEmpty) {
          final firstItem = items[0];
          final String rawTitle = firstItem['title'];
          final int totalPrice = int.parse(firstItem['lprice']);
          final String link = firstItem['link'];

          // 쇼핑몰 이름
          final String mallName = firstItem['mallName'];

          // OpenAI Structured Outputs로 데이터 정제 요청
          const openaiUrl = 'https://api.openai.com/v1/chat/completions';
          final openaiResponse = await http.post(
            Uri.parse(openaiUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $openaiKey',
            },
            body: jsonEncode({
              'model': 'gpt-4o-mini',
              'messages': [
                {
                  'role': 'system',
                  'content': '너는 쇼핑 데이터 분석가야. 상품명에서 총 수량(개수)을 파악하고 단가를 계산해 무조건 지정된 JSON 스키마로만 응답해.'
                },
                {
                  'role': 'user',
                  'content': '상품명: $rawTitle, 전체가격: $totalPrice원'
                }
              ],
              'response_format': {
                'type': 'json_schema',
                'json_schema': {
                  'name': 'product_analysis',
                  'strict': true,
                  'schema': {
                    'type': 'object',
                    'properties': {
                      'total_count': {'type': 'integer'},
                      'unit_price': {'type': 'integer'},
                      'pure_name': {'type': 'string'}
                    },
                    'required': ['total_count', 'unit_price', 'pure_name'],
                    'additionalProperties': false
                  }
                }
              }
            }),
          );

          if (openaiResponse.statusCode == 200) {
            final openaiData = jsonDecode(utf8.decode(openaiResponse.bodyBytes));
            final String aiJsonString = openaiData['choices'][0]['message']['content'];
            final Map<String, dynamic> aiResult = jsonDecode(aiJsonString);

            // AI가 계산해 준 단가를 UI 모델에 매핑
            final int unitPrice = aiResult['unit_price'];
            final int totalCount = aiResult['total_count'];
            final String pureName = aiResult['pure_name'];

            
            final lowestPrice = PriceComparison(
              store: '[$mallName] $pureName (총 $totalCount개 / 개당 $unitPrice원)', 
              price: totalPrice,
              isLowest: true,
            );

            if (mounted) {
              setState(() {
                _realPriceData = [lowestPrice];
                _buyLink = link; // 나중에 터치 시 이동할 링크 저장
                _isLoadingPrice = false;
              });
            }
            return;
          }
        }
      }
      
      // 검색 결과가 없거나 통신 에러 시 예외 처리
      if (mounted) setState(() => _isLoadingPrice = false);
      
    } catch (e) {
      debugPrint('통신 및 파싱 에러: $e');
      if (mounted) setState(() => _isLoadingPrice = false);
    }
  }

  @override
  void dispose() {
    ItemStore.instance.removeListener(_onStoreChanged);
    super.dispose();
  }

  // 스토어 변경 시 현재 아이템 갱신 (삭제됐으면 자동으로 뒤로 이동)
  void _onStoreChanged() {
    final found = ItemStore.instance.findById(_item.id);
    if (found == null) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    if (mounted) setState(() => _item = found);
  }

  // 편집 화면으로 이동
  void _openEdit() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddItemScreen(editItem: _item)),
    );
  }

  // 삭제 확인 다이얼로그
  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('제품 삭제'),
        content: Text('\'${_item.name}\'을(를) 삭제하시겠습니까?\n삭제 후 복구할 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ItemStore.instance.delete(_item.id);
        // _onStoreChanged가 자동으로 pop 처리
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('제품을 삭제하지 못했어요. 잠시 후 다시 시도해주세요.'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    }
  }

  String _formatPrice(int price) {
    final str = price.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write(',');
      buffer.write(str[i]);
    }
    return '$buffer원';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_item.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: '편집',
            onPressed: _openEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.danger),
            tooltip: '삭제',
            onPressed: _confirmDelete,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProductHeader(),
            const SizedBox(height: 24),
            _buildReplacementCycle(),
            const SizedBox(height: 20),
            _buildPriceComparison(),
            const SizedBox(height: 20),
            if (_item.purchaseHistory.isNotEmpty) ...[
              _buildPurchaseHistory(),
              const SizedBox(height: 20),
            ],
            _buildActionButtons(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildProductHeader() {
    final hasImage = _item.imageUrl != null && _item.imageUrl!.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 이미지 배너 (imageUrl이 있을 때만)
          if (hasImage)
            SizedBox(
              width: double.infinity,
              height: 220,
              child: Image.network(
                _item.imageUrl!,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    color: AppColors.primaryLight2,
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                },
                errorBuilder: (_, error, stack) => Container(
                  color: AppColors.primaryLight2,
                  child: const Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      size: 48,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            ),
          // 제품 정보 행
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                if (!hasImage)
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight2,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(_item.icon, color: AppColors.primary, size: 32),
                  ),
                if (!hasImage) const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight2,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _item.category,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _item.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _item.brand,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                CountdownRing(
                  daysRemaining: _item.daysRemaining,
                  totalDays: _item.cycleDays,
                  size: 100,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplacementCycle() {
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
          const Text(
            '교체 주기',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 16),
          _cycleRow(
            '사용자 설정',
            '${_item.cycleDays}일',
            Icons.person_outline,
            AppColors.textSecondary,
          ),
          if (_item.aiPredictedDays != null) ...[
            const SizedBox(height: 12),
            _cycleRow(
              'AI 예측',
              '${_item.aiPredictedDays}일',
              Icons.auto_awesome_outlined,
              AppColors.primary,
            ),
            if (_item.aiConfidence != null) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 36),
                child: Row(
                  children: [
                    Text(
                      '신뢰도 ${(_item.aiConfidence! * 100).toInt()}%',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: _item.aiConfidence!,
                          minHeight: 4,
                          backgroundColor: AppColors.border,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _cycleRow(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildPriceComparison() {
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
          
          // 데이터 분기 처리 적용
          if (_isLoadingPrice)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_realPriceData.isEmpty)
            const Text(
              '최저가 정보를 불러올 수 없습니다.',
              style: TextStyle(color: AppColors.textMuted),
            )
          else
            ..._realPriceData.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
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
                        p.store, // 여기에 "제주삼다수 (총 12개 / 개당 1,033원)" 형태가 들어갑니다.
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: p.isLowest ? FontWeight.w600 : FontWeight.w400,
                          color: p.isLowest ? AppColors.text : AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis, // 글자가 길면 줄임표 처리
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _formatPrice(p.price),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: p.isLowest ? FontWeight.w700 : FontWeight.w400,
                        color: p.isLowest ? AppColors.success : AppColors.text,
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

  Widget _buildPurchaseHistory() {
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
          Row(
            children: [
              const Text(
                '구매 이력',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_item.purchaseHistory.length}건',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._item.purchaseHistory.asMap().entries.map((entry) {
            final i = entry.key;
            final record = entry.value;
            final isFirst = i == 0;
            final isLast = i == _item.purchaseHistory.length - 1;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 5),
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isFirst ? AppColors.primary : AppColors.border,
                        ),
                      ),
                      if (!isLast)
                        Container(
                          width: 1.5,
                          height: 52,
                          color: AppColors.border,
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${record.date.year}.${record.date.month.toString().padLeft(2, '0')}.${record.date.day.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isFirst
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: AppColors.text,
                                ),
                              ),
                              if (record.store.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  record.store,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (record.price > 0)
                          Text(
                            _formatPrice(record.price),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isFirst
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isFirst
                                  ? AppColors.text
                                  : AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: _openEdit,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('정보 수정'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _confirmDelete,
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('삭제'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.danger),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
