import 'package:flutter/foundation.dart';

import '../models/item.dart';

class SampleData {
  static List<ConsumableItem> get items => itemsFor(DateTime.now());

  @visibleForTesting
  static List<ConsumableItem> itemsFor(DateTime now) {
    final today = _normalizedDate(now);

    return [
      _item(
        today: today,
        id: '1',
        name: '정수기 필터',
        brand: '코웨이',
        category: '가전/필터',
        cycleDays: 90,
        aiPredictedDays: 88,
        aiConfidence: 0.93,
        purchaseHistory: [
          _purchase(today, 14, 34900, '코웨이몰'),
          _purchase(today, 104, 35900, '쿠팡'),
          _purchase(today, 196, 34500, '네이버쇼핑'),
        ],
      ),
      _item(
        today: today,
        id: '2',
        name: '주방 세제',
        brand: '자연퐁',
        category: '주방/세제',
        cycleDays: 32,
        aiPredictedDays: 30,
        aiConfidence: 0.89,
        purchaseHistory: [
          _purchase(today, 8, 4980, '이마트'),
          _purchase(today, 39, 4700, '쿠팡'),
          _purchase(today, 71, 5200, '홈플러스'),
        ],
      ),
      _item(
        today: today,
        id: '3',
        name: '세탁 세제',
        brand: '퍼실',
        category: '세탁/청소',
        cycleDays: 48,
        aiPredictedDays: 45,
        aiConfidence: 0.87,
        purchaseHistory: [
          _purchase(today, 11, 18900, '쿠팡'),
          _purchase(today, 58, 19200, 'SSG닷컴'),
          _purchase(today, 102, 18500, '코스트코'),
        ],
      ),
      _item(
        today: today,
        id: '4',
        name: '화장지',
        brand: '코디',
        category: '욕실/위생',
        cycleDays: 36,
        aiPredictedDays: 34,
        aiConfidence: 0.86,
        purchaseHistory: [
          _purchase(today, 6, 15900, '마켓컬리'),
          _purchase(today, 33, 15400, '쿠팡'),
          _purchase(today, 65, 16200, '이마트'),
        ],
      ),
      _item(
        today: today,
        id: '5',
        name: '치약',
        brand: '덴티스테',
        category: '욕실/위생',
        cycleDays: 70,
        aiPredictedDays: 68,
        aiConfidence: 0.84,
        purchaseHistory: [
          _purchase(today, 16, 9900, '올리브영'),
          _purchase(today, 81, 9800, '쿠팡'),
          _purchase(today, 149, 9500, '네이버쇼핑'),
        ],
      ),
      _item(
        today: today,
        id: '6',
        name: '샴푸',
        brand: '케라시스',
        category: '헤어/바디',
        cycleDays: 65,
        aiPredictedDays: 63,
        aiConfidence: 0.82,
        purchaseHistory: [
          _purchase(today, 10, 12900, '올리브영'),
          _purchase(today, 72, 12500, '쿠팡'),
          _purchase(today, 138, 13100, '롯데온'),
        ],
      ),
      _item(
        today: today,
        id: '7',
        name: '샤워기 필터',
        brand: '바디럽',
        category: '가전/필터',
        cycleDays: 100,
        aiPredictedDays: 96,
        aiConfidence: 0.85,
        purchaseHistory: [
          _purchase(today, 19, 17900, '오늘의집'),
          _purchase(today, 109, 17500, '쿠팡'),
          _purchase(today, 202, 17200, '네이버쇼핑'),
        ],
      ),
      _item(
        today: today,
        id: '8',
        name: '식기세척기 세제',
        brand: '프로쉬',
        category: '주방/세제',
        cycleDays: 45,
        aiPredictedDays: 43,
        aiConfidence: 0.88,
        purchaseHistory: [
          _purchase(today, 13, 11900, '쿠팡'),
          _purchase(today, 55, 12200, 'SSG닷컴'),
          _purchase(today, 97, 11800, '이마트'),
        ],
      ),
      _item(
        today: today,
        id: '9',
        name: '욕실 세정제',
        brand: '홈스타',
        category: '욕실/위생',
        cycleDays: 40,
        aiPredictedDays: 38,
        aiConfidence: 0.83,
        purchaseHistory: [
          _purchase(today, 18, 6900, '홈플러스'),
          _purchase(today, 51, 6500, '쿠팡'),
          _purchase(today, 92, 6700, '이마트'),
        ],
      ),
      _item(
        today: today,
        id: '10',
        name: '건조기 시트',
        brand: '다우니',
        category: '세탁/청소',
        cycleDays: 35,
        aiPredictedDays: 33,
        aiConfidence: 0.86,
        purchaseHistory: [
          _purchase(today, 9, 10900, '쿠팡'),
          _purchase(today, 43, 11200, '마켓컬리'),
          _purchase(today, 77, 10500, '롯데마트'),
        ],
      ),
      _item(
        today: today,
        id: '11',
        name: '에어컨 필터',
        brand: '삼성',
        category: '가전/필터',
        cycleDays: 150,
        aiPredictedDays: 145,
        aiConfidence: 0.79,
        purchaseHistory: [
          _purchase(today, 20, 24900, '삼성닷컴'),
          _purchase(today, 167, 24500, '쿠팡'),
          _purchase(today, 348, 23900, '하이마트'),
        ],
      ),
      _item(
        today: today,
        id: '12',
        name: '바디워시',
        brand: '해피바스',
        category: '헤어/바디',
        cycleDays: 38,
        aiPredictedDays: 36,
        aiConfidence: 0.81,
        purchaseHistory: [
          _purchase(today, 12, 8900, '올리브영'),
          _purchase(today, 46, 9100, '쿠팡'),
          _purchase(today, 88, 8700, '네이버쇼핑'),
        ],
      ),
    ];
  }

  static const List<PriceComparison> priceComparisons = [
    PriceComparison(store: '쿠팡', price: 32900, isLowest: true),
    PriceComparison(store: '네이버쇼핑', price: 33800),
    PriceComparison(store: '마켓컬리', price: 34900),
    PriceComparison(store: 'SSG닷컴', price: 35500),
  ];

  static const List<GroupMember> groupMembers = [
    GroupMember(name: '사용자', avatarColor: '0xFF0891B2'),
    GroupMember(name: '가족 A', avatarColor: '0xFFD97706'),
    GroupMember(name: '가족 B', avatarColor: '0xFF059669'),
    GroupMember(name: '가족 C', avatarColor: '0xFF7C3AED'),
  ];

  static ConsumableItem _item({
    required DateTime today,
    required String id,
    required String name,
    required String brand,
    required String category,
    required int cycleDays,
    required List<PurchaseRecord> purchaseHistory,
    int? aiPredictedDays,
    double? aiConfidence,
  }) {
    final sortedHistory = List<PurchaseRecord>.from(purchaseHistory)
      ..sort((a, b) => b.date.compareTo(a.date));
    final daysSinceLastPurchase = today
        .difference(sortedHistory.first.date)
        .inDays;
    final progress = (daysSinceLastPurchase / cycleDays)
        .clamp(0.0, 1.0)
        .toDouble();

    return ConsumableItem(
      id: id,
      name: name,
      brand: brand,
      category: category,
      icon: ConsumableItem.iconForCategory(category),
      daysRemaining: cycleDays - daysSinceLastPurchase,
      cycleDays: cycleDays,
      progress: progress,
      aiPredictedDays: aiPredictedDays,
      aiConfidence: aiConfidence,
      purchaseHistory: sortedHistory,
      createdAt: sortedHistory.last.date,
    );
  }

  static PurchaseRecord _purchase(
    DateTime today,
    int daysAgo,
    int price,
    String store,
  ) {
    return PurchaseRecord(
      date: _daysAgo(today, daysAgo),
      price: price,
      store: store,
    );
  }

  static DateTime _daysAgo(DateTime today, int days) {
    return DateTime(today.year, today.month, today.day - days);
  }

  static DateTime _normalizedDate(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}
