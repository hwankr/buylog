import 'package:buylog/models/item.dart';
import 'package:flutter/material.dart';

class RecentPurchaseRecord {
  const RecentPurchaseRecord({
    required this.itemId,
    required this.itemName,
    required this.brand,
    required this.icon,
    required this.date,
    required this.price,
    required this.store,
  });

  final String itemId;
  final String itemName;
  final String brand;
  final IconData icon;
  final DateTime date;
  final int price;
  final String store;
}

class RecentPurchaseService {
  static List<RecentPurchaseRecord> fromItems(
    List<ConsumableItem> items, {
    int limit = 3,
  }) {
    if (items.isEmpty || limit <= 0) {
      return const <RecentPurchaseRecord>[];
    }

    final rows =
        items
            .expand(
              (item) => item.purchaseHistory.map(
                (purchase) => RecentPurchaseRecord(
                  itemId: item.id,
                  itemName: item.name,
                  brand: item.brand,
                  icon: item.icon,
                  date: purchase.date,
                  price: purchase.price,
                  store: purchase.store,
                ),
              ),
            )
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));

    return _takeLimit(rows, limit);
  }

  static List<RecentPurchaseRecord> fromPurchaseRows(
    List<Map<String, dynamic>> rows, {
    int limit = 3,
    String? userId,
  }) {
    if (rows.isEmpty || limit <= 0) {
      return const <RecentPurchaseRecord>[];
    }

    final parsed = <_ParsedRecentPurchase>[];

    for (final row in rows) {
      final purchasedBy = row['purchased_by'] as String?;
      if (userId != null && purchasedBy != userId) {
        continue;
      }

      final product = _coerceSingleMap(row['product_items']);
      if (product == null) {
        continue;
      }

      final itemId = product['id'] as String?;
      final itemName = product['name'] as String?;
      final purchaseDate = _tryParseDateTime(row['purchase_date']);

      if (itemId == null || itemName == null || purchaseDate == null) {
        continue;
      }

      final category = _coerceSingleMap(product['categories']);
      final categoryName = category?['name'] as String? ?? '기타';

      parsed.add(
        _ParsedRecentPurchase(
          record: RecentPurchaseRecord(
            itemId: itemId,
            itemName: itemName,
            brand: product['brand'] as String? ?? '',
            icon: ConsumableItem.iconForCategory(categoryName),
            date: purchaseDate,
            price: (row['price'] as num?)?.toInt() ?? 0,
            store: row['store_name'] as String? ?? '',
          ),
          createdAt: _tryParseDateTime(row['created_at']),
        ),
      );
    }

    parsed.sort((a, b) {
      final byPurchaseDate = b.record.date.compareTo(a.record.date);
      if (byPurchaseDate != 0) {
        return byPurchaseDate;
      }

      if (a.createdAt == null && b.createdAt == null) {
        return 0;
      }
      if (a.createdAt == null) {
        return 1;
      }
      if (b.createdAt == null) {
        return -1;
      }
      return b.createdAt!.compareTo(a.createdAt!);
    });

    return _takeLimit(parsed.map((entry) => entry.record).toList(), limit);
  }

  static DateTime? _tryParseDateTime(dynamic value) {
    if (value is! String) {
      return null;
    }
    return DateTime.tryParse(value);
  }

  static List<RecentPurchaseRecord> _takeLimit(
    List<RecentPurchaseRecord> rows,
    int limit,
  ) {
    if (rows.length <= limit) {
      return rows;
    }
    return rows.take(limit).toList();
  }

  static Map<String, dynamic>? _coerceSingleMap(dynamic value) {
    final direct = _asStringMap(value);
    if (direct != null) {
      return direct;
    }

    if (value is List) {
      for (final entry in value) {
        final map = _asStringMap(entry);
        if (map != null) {
          return map;
        }
      }
    }

    return null;
  }

  static Map<String, dynamic>? _asStringMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, entry) => MapEntry('$key', entry));
    }
    return null;
  }
}

class _ParsedRecentPurchase {
  const _ParsedRecentPurchase({required this.record, required this.createdAt});

  final RecentPurchaseRecord record;
  final DateTime? createdAt;
}
