import 'package:flutter/material.dart';
import '../services/ai/prediction_service.dart';

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

    // 구매 날짜 리스트 추출
    List<DateTime> purchaseDates = history.map((p) => p.date).toList();

    // DB에서 기본 주기 및 등록일 가져오기
    final int defaultCycle = json['replacement_cycle_days'] ?? 30;
    // 등록일이 없으면 현재 시간으로 처리
    final DateTime registeredAt = json['created_at'] != null
        ? DateTime.parse(json['created_at'])
        : DateTime.now();

    final prediction = predictCycle(
      purchaseDates: purchaseDates,
      categoryDefaultDays: defaultCycle,
    );

    // 예측 주기를 바탕으로 D-Day 계산
    final int calculatedDays = calcDday(
      purchaseDates: purchaseDates,
      predictedCycleDays: prediction.predictedCycleDays,
      registeredAt: registeredAt,
    );

    // 잔여량
    final double progress = calcRemainingPercent(
      purchaseDates: purchaseDates,
      predictedCycleDays: prediction.predictedCycleDays,
      registeredAt: registeredAt,
    );

    return ConsumableItem(
      id: json['id'].toString(),
      name: json['name'] ?? '이름 없음',
      brand: json['brand'] ?? '브랜드 없음',
      category: '기타',
      icon: Icons.inventory_2_outlined,

      daysRemaining: calculatedDays,
      cycleDays: prediction.predictedCycleDays,
      progress: progress,

      // Phase에 따른 정밀한 예측일수와 신뢰도 반영
      aiPredictedDays: prediction.predictedCycleDays,
      aiConfidence: prediction.confidence,

      imageUrl: json['image_url'],
      purchaseHistory: history,
    );
  }
}

class PurchaseRecord {
  final DateTime date; // 구매 날짜
  final int price; // 구매 가격
  final String store; // 구매처

  const PurchaseRecord({
    required this.date,
    required this.price,
    required this.store,
  });

  // JSON -> PurchaseRecord 객체 변환
  factory PurchaseRecord.fromJson(Map<String, dynamic> json) {
    return PurchaseRecord(
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
