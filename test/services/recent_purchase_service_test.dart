import 'package:buylog/models/item.dart';
import 'package:buylog/services/recent_purchase_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RecentPurchaseService.fromItems', () {
    test('returns newest-first purchases, applies limit, and maps fields', () {
      final items = <ConsumableItem>[
        ConsumableItem(
          id: 'item-1',
          name: '세탁세제',
          brand: '브랜드A',
          category: '세탁',
          icon: Icons.local_laundry_service_outlined,
          daysRemaining: 4,
          cycleDays: 30,
          progress: 0.5,
          purchaseHistory: [
            PurchaseRecord(
              date: DateTime(2026, 5, 1),
              price: 8900,
              store: '쿠팡',
            ),
            PurchaseRecord(
              date: DateTime(2026, 4, 15),
              price: 7900,
              store: '홈플러스',
            ),
          ],
        ),
        ConsumableItem(
          id: 'item-2',
          name: '주방세제',
          brand: '브랜드B',
          category: '주방',
          icon: Icons.kitchen_outlined,
          daysRemaining: 8,
          cycleDays: 40,
          progress: 0.3,
          purchaseHistory: [
            PurchaseRecord(
              date: DateTime(2026, 5, 5),
              price: 4900,
              store: '홈플러스',
            ),
            PurchaseRecord(
              date: DateTime(2026, 4, 30),
              price: 4500,
              store: '다이소',
            ),
          ],
        ),
      ];

      final rows = RecentPurchaseService.fromItems(items);

      expect(rows, hasLength(3));
      expect(rows[0].itemId, 'item-2');
      expect(rows[0].itemName, '주방세제');
      expect(rows[0].brand, '브랜드B');
      expect(rows[0].icon, Icons.kitchen_outlined);
      expect(rows[0].date, DateTime(2026, 5, 5));
      expect(rows[0].price, 4900);
      expect(rows[0].store, '홈플러스');
      expect(rows[1].date, DateTime(2026, 5, 1));
      expect(rows[1].itemId, 'item-1');
      expect(rows[2].date, DateTime(2026, 4, 30));
      expect(rows[2].itemId, 'item-2');
    });

    test('returns empty list when every item has empty purchase history', () {
      final items = <ConsumableItem>[
        ConsumableItem(
          id: 'item-1',
          name: '휴지',
          brand: '브랜드A',
          category: '생활',
          icon: Icons.category_outlined,
          daysRemaining: 10,
          cycleDays: 30,
          progress: 0.2,
        ),
        ConsumableItem(
          id: 'item-2',
          name: '물티슈',
          brand: '브랜드B',
          category: '생활',
          icon: Icons.category_outlined,
          daysRemaining: 5,
          cycleDays: 20,
          progress: 0.5,
        ),
      ];

      final rows = RecentPurchaseService.fromItems(items);

      expect(rows, isEmpty);
    });

    test('returns empty list for empty input', () {
      final rows = RecentPurchaseService.fromItems(const []);

      expect(rows, isEmpty);
    });

    test('returns empty list when limit is zero', () {
      final items = <ConsumableItem>[
        ConsumableItem(
          id: 'item-1',
          name: '휴지',
          brand: '브랜드A',
          category: '생활',
          icon: Icons.category_outlined,
          daysRemaining: 10,
          cycleDays: 30,
          progress: 0.2,
          purchaseHistory: [
            PurchaseRecord(
              date: DateTime(2026, 5, 1),
              price: 1000,
              store: '마트',
            ),
          ],
        ),
      ];

      final rows = RecentPurchaseService.fromItems(items, limit: 0);

      expect(rows, isEmpty);
    });
  });

  group('RecentPurchaseService.fromPurchaseRows', () {
    test(
      'returns purchase-recency rows newest first even when the newest purchase belongs to an older item',
      () {
        final rows = [
          {
            'id': 'purchase-1',
            'purchase_date': '2026-05-06',
            'price': 15900,
            'store_name': '코스트코',
            'product_items': {
              'id': 'older-item',
              'name': '대용량 세제',
              'brand': '브랜드A',
              'categories': {'name': '세탁'},
            },
          },
          {
            'id': 'purchase-2',
            'purchase_date': '2026-05-04',
            'price': 4900,
            'store_name': '홈플러스',
            'product_items': {
              'id': 'newer-item',
              'name': '주방세제',
              'brand': '브랜드B',
              'categories': {'name': '주방'},
            },
          },
        ];

        final parsed = RecentPurchaseService.fromPurchaseRows(rows);

        expect(parsed, hasLength(2));
        expect(parsed.first.itemId, 'older-item');
        expect(parsed.first.itemName, '대용량 세제');
        expect(parsed.first.icon, ConsumableItem.iconForCategory('세탁'));
        expect(parsed.first.store, '코스트코');
        expect(parsed.first.date, DateTime(2026, 5, 6));
        expect(parsed.last.itemId, 'newer-item');
      },
    );

    test('applies positive limit after sorting newest first', () {
      final rows = [
        {
          'id': 'purchase-older',
          'purchase_date': '2026-05-02',
          'price': 3000,
          'store_name': '다이소',
          'product_items': {
            'id': 'item-1',
            'name': '휴지',
            'brand': '브랜드A',
            'categories': {'name': '생활'},
          },
        },
        {
          'id': 'purchase-newest',
          'purchase_date': '2026-05-06',
          'price': 5000,
          'store_name': '쿠팡',
          'product_items': {
            'id': 'item-2',
            'name': '물티슈',
            'brand': '브랜드B',
            'categories': {'name': '생활'},
          },
        },
        {
          'id': 'purchase-second',
          'purchase_date': '2026-05-04',
          'price': 4200,
          'store_name': '홈플러스',
          'product_items': {
            'id': 'item-3',
            'name': '주방세제',
            'brand': '브랜드C',
            'categories': {'name': '주방'},
          },
        },
      ];

      final parsed = RecentPurchaseService.fromPurchaseRows(rows, limit: 2);

      expect(parsed, hasLength(2));
      expect(parsed[0].itemId, 'item-2');
      expect(parsed[0].icon, ConsumableItem.iconForCategory('생활'));
      expect(parsed[0].date, DateTime(2026, 5, 6));
      expect(parsed[1].itemId, 'item-3');
      expect(parsed[1].icon, ConsumableItem.iconForCategory('주방'));
      expect(parsed[1].date, DateTime(2026, 5, 4));
    });

    test('uses created_at as a tie breaker when purchase_date is the same', () {
      final rows = [
        {
          'id': 'purchase-early',
          'purchase_date': '2026-05-06',
          'created_at': '2026-05-06T08:00:00Z',
          'price': 4000,
          'store_name': '마트',
          'product_items': {
            'id': 'item-1',
            'name': '휴지',
            'brand': '브랜드A',
            'categories': {'name': '생활'},
          },
        },
        {
          'id': 'purchase-late',
          'purchase_date': '2026-05-06',
          'created_at': '2026-05-06T20:00:00Z',
          'price': 5000,
          'store_name': '쿠팡',
          'product_items': {
            'id': 'item-2',
            'name': '물티슈',
            'brand': '브랜드B',
            'categories': {'name': '생활'},
          },
        },
      ];

      final parsed = RecentPurchaseService.fromPurchaseRows(rows, limit: 2);

      expect(parsed.map((row) => row.itemId), ['item-2', 'item-1']);
      expect(parsed.first.store, '쿠팡');
    });

    test('returns empty list when helper limit is non-positive', () {
      final validRows = [
        {
          'id': 'purchase-1',
          'purchase_date': '2026-05-06',
          'created_at': '2026-05-06T20:00:00Z',
          'price': 5000,
          'store_name': '쿠팡',
          'product_items': {
            'id': 'item-2',
            'name': '물티슈',
            'brand': '브랜드B',
            'categories': {'name': '생활'},
          },
        },
      ];

      expect(
        RecentPurchaseService.fromPurchaseRows(validRows, limit: 0),
        isEmpty,
      );
      expect(
        RecentPurchaseService.fromPurchaseRows(validRows, limit: -1),
        isEmpty,
      );
    });

    test('filters out rows for other users when userId is provided', () {
      final rows = [
        {
          'id': 'purchase-1',
          'purchased_by': 'user-1',
          'purchase_date': '2026-05-06',
          'price': 5000,
          'store_name': '쿠팡',
          'product_items': {
            'id': 'item-1',
            'name': '물티슈',
            'brand': '브랜드A',
            'categories': {'name': '생활'},
          },
        },
        {
          'id': 'purchase-2',
          'purchased_by': 'user-2',
          'purchase_date': '2026-05-07',
          'price': 7000,
          'store_name': '홈플러스',
          'product_items': {
            'id': 'item-2',
            'name': '주방세제',
            'brand': '브랜드B',
            'categories': {'name': '주방'},
          },
        },
      ];

      final parsed = RecentPurchaseService.fromPurchaseRows(
        rows,
        userId: 'user-1',
      );

      expect(parsed, hasLength(1));
      expect(parsed.single.itemId, 'item-1');
      expect(parsed.single.store, '쿠팡');
    });

    test('skips malformed rows and returns empty list for empty input', () {
      final rows = [
        <String, dynamic>{},
        {
          'id': 'missing-product',
          'purchase_date': '2026-05-06',
          'price': 1000,
          'store_name': '마트',
          'product_items': null,
        },
        {
          'id': 'bad-date',
          'purchase_date': 'not-a-date',
          'price': 1000,
          'store_name': '마트',
          'product_items': {
            'id': 'item-1',
            'name': '휴지',
            'brand': '브랜드A',
            'categories': {'name': '생활'},
          },
        },
        {
          'id': 'valid',
          'purchase_date': '2026-05-01',
          'price': 3200,
          'store_name': '다이소',
          'product_items': {
            'id': 'item-2',
            'name': '물티슈',
            'brand': '브랜드B',
            'categories': null,
          },
        },
      ];

      expect(RecentPurchaseService.fromPurchaseRows(const []), isEmpty);

      final parsed = RecentPurchaseService.fromPurchaseRows(rows);

      expect(parsed, hasLength(1));
      expect(parsed.single.itemId, 'item-2');
      expect(parsed.single.itemName, '물티슈');
      expect(parsed.single.brand, '브랜드B');
      expect(parsed.single.price, 3200);
      expect(parsed.single.store, '다이소');
    });
  });
}
