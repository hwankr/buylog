import '../models/item.dart'; // PriceComparison 사용

class PriceCacheData {
  final List<PriceComparison> priceData;
  final String buyLink;
  final DateTime fetchedAt;

  PriceCacheData({
    required this.priceData,
    required this.buyLink,
    required this.fetchedAt,
  });

  // 캐시 만료 여부 확인 (예: 1시간이 지나면 만료된 것으로 처리)
  bool get isExpired => DateTime.now().difference(fetchedAt).inHours >= 1;
}