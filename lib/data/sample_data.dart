import 'package:flutter/material.dart';
import '../models/item.dart';

class SampleData {
  static final List<ConsumableItem> items = [
    ConsumableItem(
      id: '1',
      name: '정수기 필터',
      brand: '코웨이',
      category: '필터',
      icon: Icons.water_drop_outlined,
      daysRemaining: 3,
      cycleDays: 90,
      progress: 0.97,
      aiPredictedDays: 85,
      aiConfidence: 0.92,
      purchaseHistory: [
        PurchaseRecord(date: DateTime(2026, 1, 5), price: 35000, store: '쿠팡'),
        PurchaseRecord(date: DateTime(2025, 10, 8), price: 37000, store: '네이버'),
        PurchaseRecord(date: DateTime(2025, 7, 12), price: 34500, store: '쿠팡'),
      ],
    ),
    ConsumableItem(
      id: '2',
      name: '세탁세제',
      brand: '피죤',
      category: '세탁',
      icon: Icons.local_laundry_service_outlined,
      daysRemaining: 12,
      cycleDays: 45,
      progress: 0.73,
      aiPredictedDays: 42,
      aiConfidence: 0.87,
      purchaseHistory: [
        PurchaseRecord(date: DateTime(2026, 3, 1), price: 15900, store: '이마트'),
        PurchaseRecord(date: DateTime(2026, 1, 15), price: 16500, store: '쿠팡'),
      ],
    ),
    ConsumableItem(
      id: '3',
      name: '칫솔',
      brand: '오랄비',
      category: '위생',
      icon: Icons.brush_outlined,
      daysRemaining: 25,
      cycleDays: 90,
      progress: 0.72,
      aiPredictedDays: 88,
      aiConfidence: 0.78,
      purchaseHistory: [
        PurchaseRecord(date: DateTime(2026, 2, 20), price: 8900, store: '다이소'),
      ],
    ),
    ConsumableItem(
      id: '4',
      name: '에어컨 필터',
      brand: '삼성',
      category: '필터',
      icon: Icons.air_outlined,
      daysRemaining: 45,
      cycleDays: 180,
      progress: 0.75,
      aiPredictedDays: 170,
      aiConfidence: 0.65,
      purchaseHistory: [
        PurchaseRecord(date: DateTime(2025, 12, 1), price: 22000, store: '삼성몰'),
      ],
    ),
    ConsumableItem(
      id: '5',
      name: '주방세제',
      brand: '퐁퐁',
      category: '주방',
      icon: Icons.kitchen_outlined,
      daysRemaining: 7,
      cycleDays: 30,
      progress: 0.77,
      aiPredictedDays: 28,
      aiConfidence: 0.91,
      purchaseHistory: [
        PurchaseRecord(date: DateTime(2026, 3, 20), price: 4500, store: '이마트'),
        PurchaseRecord(date: DateTime(2026, 2, 18), price: 4200, store: '쿠팡'),
      ],
    ),
    ConsumableItem(
      id: '6',
      name: '샴푸',
      brand: '케라시스',
      category: '위생',
      icon: Icons.shower_outlined,
      daysRemaining: 18,
      cycleDays: 60,
      progress: 0.70,
      purchaseHistory: [
<<<<<<< HEAD
        PurchaseRecord(date: DateTime(2026, 2, 10), price: 12800, store: '올리브영'),
=======
        PurchaseRecord(
          date: DateTime(2026, 2, 10),
          price: 12800,
          store: '올리브영',
        ),
>>>>>>> develop
      ],
    ),
  ];

  static final List<PriceComparison> priceComparisons = [
    const PriceComparison(store: '쿠팡', price: 33500, isLowest: true),
    const PriceComparison(store: '네이버', price: 35000),
    const PriceComparison(store: '이마트', price: 36900),
    const PriceComparison(store: '삼성몰', price: 37500),
  ];

  static final List<GroupMember> groupMembers = [
    const GroupMember(name: '나', avatarColor: '0xFF0891B2'),
    const GroupMember(name: '엄마', avatarColor: '0xFFD97706'),
    const GroupMember(name: '아빠', avatarColor: '0xFF059669'),
    const GroupMember(name: '동생', avatarColor: '0xFF7C3AED'),
  ];
}
