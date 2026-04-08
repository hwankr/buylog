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
}

class PurchaseRecord {
  final DateTime date;
  final int price;
  final String store;

  const PurchaseRecord({
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
