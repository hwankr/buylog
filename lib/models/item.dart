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
  });

  factory ConsumableItem.fromJson(Map<String, dynamic> json) {
    // 구매 이력 추출
    var purchasesJson = json['purchases'] as List<dynamic>? ?? [];
    List<PurchaseRecord> history = purchasesJson
        .map((p) => PurchaseRecord.fromJson(p as Map<String, dynamic>))
        .toList();

    // DB에서 주기 가져오기 (없으면 기본 30일)
    final int cycle = json['replacement_cycle_days'] ?? 30;

    int calculatedDays;
    double progress;

    if (history.isNotEmpty) {
      // 최근 구매일 기준 D-Day 계산 로직
      final lastPurchase = history.first.date;
      final nextReplacement = lastPurchase.add(Duration(days: cycle));
      calculatedDays = nextReplacement.difference(DateTime.now()).inDays;

      // 잔량 게이지 계산 (남은날짜 / 전체주기)
      progress = (calculatedDays / cycle).clamp(0.0, 1.0);
    } else {
      // 구매 기록 없으면 새 제품으로 간주
      calculatedDays = cycle;
      progress = 1.0;
    }

    return ConsumableItem(
      id: json['id'].toString(),
      name: json['name'] ?? '이름 없음',
      brand: json['brand'] ?? '브랜드 없음',
      category: '기타', // 나중에 category_id로 이름 가져오는 로직 추가 가능
      icon: Icons.inventory_2_outlined,
      daysRemaining: calculatedDays,
      cycleDays: cycle,
      progress: progress,
      imageUrl: json['image_url'],
      purchaseHistory: history,
    );
  }
}

class PurchaseRecord {
  final DateTime date; // 구매 날짜
  final int price; // 구매 가격
  final String store; // 구매처

  PurchaseRecord({
    required this.date,
    required this.price,
    required this.store,
  });

  // JSON -> PurchaseRecord 객체 변환
  factory PurchaseRecord.fromJson(Map<String, dynamic> json) {
    return PurchaseRecord(
      // DB의 'purchase_date' 컬럼이 문자열이라고 가정하고 DateTime
      date: json['purchase_date'] != null
          ? DateTime.parse(json['purchase_date'])
          : (json['created_at'] != null 
              ? DateTime.parse(json['created_at']) 
              : DateTime.now()),
      price: json['price'] ?? 0,
      store: json['store_name'] ?? '알 수 없음',
    );
  }
}

class GroupMember {
  final String name;
  final String avatarColor;

  const GroupMember({
    required this.name,
    required this.avatarColor,
  });
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