import 'package:flutter/material.dart';

class ConsumableItem {
  final String id;
  final String name;
  final String brand;
  final String category;
  final IconData icon;
  final int daysRemaining;
  final int cycleDays;
  final double progress;
  final int? aiPredictedDays;
  final double? aiConfidence;
  final List<PurchaseRecord> purchaseHistory;
  final String? imageUrl;
  final String? groupId;
  final String? registeredBy;

  const ConsumableItem({
    required this.id,
    required this.name,
    required this.brand,
    required this.category,
    required this.icon,
    required this.daysRemaining,
    required this.cycleDays,
    required this.progress,
    this.aiPredictedDays,
    this.aiConfidence,
    this.purchaseHistory = const [],
    this.imageUrl,
    this.groupId,
    this.registeredBy,
  });

  /// Supabase product_items 행 + 관련 데이터로 ConsumableItem 생성
  ///
  /// [data]         product_items 행
  /// [categoryName] categories.name (FK join)
  /// [purchases]    purchases 행 목록 (FK join)
  /// [aiPrediction] ai_predictions 최신 행 (nullable)
  factory ConsumableItem.fromSupabase({
    required Map<String, dynamic> data,
    required String categoryName,
    required List<Map<String, dynamic>> purchases,
    Map<String, dynamic>? aiPrediction,
  }) {
    final cycleDays = (data['replacement_cycle_days'] as int?) ?? 30;

    // 구매일 내림차순 정렬
    final sorted = List<Map<String, dynamic>>.from(purchases)
      ..sort(
        (a, b) => DateTime.parse(
          b['purchase_date'],
        ).compareTo(DateTime.parse(a['purchase_date'])),
      );

    final lastDate = sorted.isNotEmpty
        ? DateTime.parse(sorted.first['purchase_date'])
        : null;

    final daysSince = lastDate != null
        ? DateTime.now().difference(lastDate).inDays
        : cycleDays;

    return ConsumableItem(
      id: data['id'] as String,
      name: data['name'] as String? ?? '',
      brand: data['brand'] as String? ?? '',
      category: categoryName,
      icon: iconForCategory(categoryName),
      daysRemaining: cycleDays - daysSince,
      cycleDays: cycleDays,
      progress: (daysSince / cycleDays).clamp(0.0, 1.0),
      imageUrl: data['image_url'] as String?,
      groupId: data['group_id'] as String?,
      registeredBy: data['registered_by'] as String?,
      aiPredictedDays: aiPrediction?['predicted_cycle_days'] as int?,
      aiConfidence: (aiPrediction?['confidence'] as num?)?.toDouble(),
      purchaseHistory: sorted
          .map(
            (p) => PurchaseRecord(
              id: p['id'] as String?,
              date: DateTime.parse(p['purchase_date']),
              price: (p['price'] as int?) ?? 0,
              store: (p['store_name'] as String?) ?? '',
            ),
          )
          .toList(),
    );
  }

  /// home_screen의 `select('*, purchases(*)')` 쿼리 결과로 생성
  factory ConsumableItem.fromJson(Map<String, dynamic> json) {
    final purchases =
        (json['purchases'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
        [];

    return ConsumableItem.fromSupabase(
      data: json,
      categoryName: '기타',
      purchases: purchases,
    );
  }

  static IconData iconForCategory(String category) {
    return switch (category) {
      '욕실/위생' => Icons.bathroom_outlined,
      '주방/세제' => Icons.kitchen_outlined,
      '세탁/청소' => Icons.local_laundry_service_outlined,
      '헤어/바디' => Icons.shower_outlined,
      '가전/필터' => Icons.air_outlined,
      _ => Icons.category_outlined,
    };
  }
}

class PurchaseRecord {
  /// Supabase purchases.id (신규 이력은 null — 저장 후 채워짐)
  final String? id;
  final DateTime date;
  final int price;
  final String store;

  const PurchaseRecord({
    this.id,
    required this.date,
    required this.price,
    required this.store,
  });
}

class GroupMember {
  final String name;
  final String avatarColor;

  const GroupMember({required this.name, required this.avatarColor});
}

class PriceComparison {
  final String store;
  final int price;
  final bool isLowest;

  const PriceComparison({
    required this.store,
    required this.price,
    this.isLowest = false,
  });
}
