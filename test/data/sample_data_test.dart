import 'package:buylog/data/sample_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SampleData regression', () {
    test('has enough items and required category coverage', () {
      expect(SampleData.items.length, greaterThanOrEqualTo(10));

      final categories = SampleData.items.map((item) => item.category).toSet();
      expect(
        categories,
        containsAll({'욕실/위생', '주방/세제', '세탁/청소', '헤어/바디', '가전/필터'}),
      );
    });

    test('every item has complete and sorted purchase history', () {
      for (final item in SampleData.items) {
        expect(
          item.name.trim(),
          isNotEmpty,
          reason: '${item.id} name is empty',
        );
        expect(
          item.brand.trim(),
          isNotEmpty,
          reason: '${item.id} brand is empty',
        );
        expect(
          item.purchaseHistory.length,
          greaterThanOrEqualTo(2),
          reason: '${item.name} must have at least 2 purchase records',
        );

        for (var i = 0; i < item.purchaseHistory.length; i++) {
          final record = item.purchaseHistory[i];
          expect(
            record.price,
            greaterThan(0),
            reason: '${item.name} has non-positive price',
          );
          expect(
            record.store.trim(),
            isNotEmpty,
            reason: '${item.name} has empty store',
          );

          if (i < item.purchaseHistory.length - 1) {
            final next = item.purchaseHistory[i + 1];
            expect(
              record.date.isAfter(next.date) ||
                  record.date.isAtSameMomentAs(next.date),
              isTrue,
              reason: '${item.name} purchaseHistory must be newest first',
            );
          }
        }
      }
    });

    test('recent six-month window contains at least 8 purchases', () {
      final now = DateTime.now();
      final windowStart = DateTime(now.year, now.month - 5, 1);

      final recentPurchaseCount = SampleData.items
          .expand((item) => item.purchaseHistory)
          .where(
            (record) =>
                !record.date.isBefore(windowStart) && !record.date.isAfter(now),
          )
          .length;

      expect(recentPurchaseCount, greaterThanOrEqualTo(8));
    });

    test('itemsFor regenerates date-relative data from normalized now', () {
      final may6Items = SampleData.itemsFor(DateTime(2026, 5, 6, 23, 59));
      final may8Items = SampleData.itemsFor(DateTime(2026, 5, 8, 23, 59));

      final may6First = may6Items.first;
      final may8First = may8Items.first;
      final may8FirstPurchase = may8First.purchaseHistory.first;

      expect(
        may8First.purchaseHistory.first.date.difference(
          may6First.purchaseHistory.first.date,
        ),
        const Duration(days: 2),
      );
      expect(may8First.daysRemaining, may6First.daysRemaining);
      expect(may8FirstPurchase.date, DateTime(2026, 4, 24));
      expect(may8FirstPurchase.date.hour, 0);
      expect(may8FirstPurchase.date.minute, 0);
    });

    test('group members use exact neutral labels', () {
      const expectedNames = ['사용자', '가족 A', '가족 B', '가족 C'];
      final memberNames = SampleData.groupMembers
          .map((member) => member.name)
          .toList();

      expect(memberNames, expectedNames);
      expect(
        memberNames.every(
          (name) => !name.contains('지민') && !name.contains('김지민'),
        ),
        isTrue,
      );
    });
  });
}
