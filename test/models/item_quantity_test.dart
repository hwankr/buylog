import 'package:buylog/models/item.dart';
import 'package:buylog/models/manual_quantity_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PurchaseRecord quantity', () {
    test('defaults to one item when quantity is omitted', () {
      final record = PurchaseRecord(
        date: DateTime(2026, 5, 30),
        price: 12000,
        store: 'Market',
      );

      expect(record.quantity, 1);
    });

    test('maps purchase quantity from Supabase rows', () {
      final item = ConsumableItem.fromSupabase(
        data: <String, dynamic>{
          'id': 'item-1',
          'name': '칫솔',
          'brand': 'Brand',
          'replacement_cycle_days': 30,
        },
        categoryName: '욕실/위생',
        purchases: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'purchase-1',
            'purchase_date': '2026-05-30',
            'price': 10000,
            'store_name': 'Market',
            'quantity': 10,
          },
        ],
      );

      expect(item.purchaseHistory.single.quantity, 10);
      expect(item.totalPurchasedQuantity, 10);
    });

    test('falls back to quantity one for older purchase rows', () {
      final item = ConsumableItem.fromSupabase(
        data: <String, dynamic>{
          'id': 'item-1',
          'name': '샴푸',
          'brand': 'Brand',
          'replacement_cycle_days': 30,
        },
        categoryName: '헤어/바디',
        purchases: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'purchase-1',
            'purchase_date': '2026-05-30',
            'price': 9000,
            'store_name': 'Market',
          },
        ],
      );

      expect(item.purchaseHistory.single.quantity, 1);
      expect(item.totalPurchasedQuantity, 1);
    });
  });

  group('ManualQuantitySnapshot', () {
    test('maps RPC response fields', () {
      final snapshot = ManualQuantitySnapshot.fromSupabase(<String, dynamic>{
        'remaining_quantity': 7,
        'confidence': 1.0,
        'source_detected_name': 'manual',
        'observed_at': '2026-05-30T12:00:00.000Z',
      });

      expect(snapshot.remainingQuantity, 7);
      expect(snapshot.confidence, 1.0);
      expect(snapshot.sourceName, 'manual');
      expect(snapshot.observedAt, DateTime.parse('2026-05-30T12:00:00.000Z'));
    });
  });
}
