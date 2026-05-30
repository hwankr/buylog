import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:buylog/models/item.dart';
import 'package:buylog/services/report_service.dart';

void main() {
  group('ReportService.aggregateRecentMonths', () {
    test('6 buckets, 오래된→최신 순, 각 월별 합계 검증', () {
      final fixture = <ConsumableItem>[
        ConsumableItem(
          id: 'a',
          name: '아이템 A',
          brand: 'brand',
          category: '위생',
          icon: Icons.circle,
          daysRemaining: 0,
          cycleDays: 30,
          progress: 0.5,
          purchaseHistory: [
            PurchaseRecord(
              date: DateTime(2025, 11, 10),
              price: 10000,
              store: 's',
            ),
            PurchaseRecord(date: DateTime(2026, 1, 5), price: 5000, store: 's'),
            PurchaseRecord(date: DateTime(2026, 4, 1), price: 3000, store: 's'),
          ],
        ),
        ConsumableItem(
          id: 'b',
          name: '아이템 B',
          brand: 'brand',
          category: '필터',
          icon: Icons.circle,
          daysRemaining: 0,
          cycleDays: 30,
          progress: 0.5,
          purchaseHistory: [
            PurchaseRecord(
              date: DateTime(2025, 12, 20),
              price: 7000,
              store: 's',
            ),
            PurchaseRecord(
              date: DateTime(2026, 3, 15),
              price: 8500,
              store: 's',
            ),
          ],
        ),
      ];

      final service = ReportService.fromItems(fixture);
      final months = service.aggregateRecentMonths(now: DateTime(2026, 4, 15));

      expect(months.length, 6);
      // 오래된 → 최신
      expect(months[0].month, DateTime(2025, 11, 1));
      expect(months[1].month, DateTime(2025, 12, 1));
      expect(months[2].month, DateTime(2026, 1, 1));
      expect(months[3].month, DateTime(2026, 2, 1));
      expect(months[4].month, DateTime(2026, 3, 1));
      expect(months[5].month, DateTime(2026, 4, 1));

      // 월별 합계
      expect(months[0].totalAmount, 10000); // Nov 2025
      expect(months[1].totalAmount, 7000); // Dec 2025
      expect(months[2].totalAmount, 5000); // Jan 2026
      expect(months[3].totalAmount, 0); // Feb 2026
      expect(months[4].totalAmount, 8500); // Mar 2026
      expect(months[5].totalAmount, 3000); // Apr 2026

      // 빈 달은 empty map/items
      expect(months[3].byCategory, isEmpty);
      expect(months[3].items, isEmpty);

      // 카테고리 귀속
      expect(months[0].byCategory, {'위생': 10000});
      expect(months[1].byCategory, {'필터': 7000});
      expect(months[4].byCategory, {'필터': 8500});
    });

    test('empty source → 6 buckets, all totals = 0', () {
      final service = ReportService.fromItems(const []);
      final months = service.aggregateRecentMonths(now: DateTime(2026, 4, 15));
      expect(months.length, 6);
      for (final m in months) {
        expect(m.totalAmount, 0);
        expect(m.byCategory, isEmpty);
        expect(m.items, isEmpty);
      }
    });
  });

  group('ReportService.categoryBreakdownFor', () {
    test('2026-03-01 breakdown: ratio 합 ≈ 1.0, amount 내림차순 정렬', () {
      final fixture = <ConsumableItem>[
        ConsumableItem(
          id: 'a',
          name: '세탁',
          brand: 'x',
          category: '세탁',
          icon: Icons.circle,
          daysRemaining: 0,
          cycleDays: 30,
          progress: 0.5,
          purchaseHistory: [
            PurchaseRecord(
              date: DateTime(2026, 3, 1),
              price: 15900,
              store: 's',
            ),
          ],
        ),
        ConsumableItem(
          id: 'b',
          name: '주방',
          brand: 'x',
          category: '주방',
          icon: Icons.circle,
          daysRemaining: 0,
          cycleDays: 30,
          progress: 0.5,
          purchaseHistory: [
            PurchaseRecord(
              date: DateTime(2026, 3, 20),
              price: 4500,
              store: 's',
            ),
          ],
        ),
        ConsumableItem(
          id: 'c',
          name: '필터',
          brand: 'x',
          category: '필터',
          icon: Icons.circle,
          daysRemaining: 0,
          cycleDays: 30,
          progress: 0.5,
          purchaseHistory: [
            PurchaseRecord(
              date: DateTime(2026, 3, 15),
              price: 8500,
              store: 's',
            ),
          ],
        ),
      ];

      final service = ReportService.fromItems(fixture);
      final breakdown = service.categoryBreakdownFor(DateTime(2026, 3, 1));

      expect(breakdown.length, 3);
      // 내림차순 정렬: 세탁(15900) > 필터(8500) > 주방(4500)
      expect(breakdown[0].category, '세탁');
      expect(breakdown[1].category, '필터');
      expect(breakdown[2].category, '주방');

      // ratio sum ≈ 1.0
      final ratioSum = breakdown.fold<double>(0, (s, c) => s + c.ratio);
      expect((ratioSum - 1.0).abs(), lessThan(1e-3));
    });

    test('데이터 없는 월 → empty list', () {
      final service = ReportService.fromItems(const []);
      final breakdown = service.categoryBreakdownFor(DateTime(2026, 3, 1));
      expect(breakdown, isEmpty);
    });
  });

  group('ReportService.itemsOfMonth', () {
    test('여러 월에 걸친 아이템은 각 월에 모두 포함된다', () {
      final sharedItem = ConsumableItem(
        id: 'shared',
        name: '주방세제',
        brand: 'p',
        category: '주방',
        icon: Icons.circle,
        daysRemaining: 0,
        cycleDays: 30,
        progress: 0.5,
        purchaseHistory: [
          PurchaseRecord(date: DateTime(2026, 2, 18), price: 4200, store: 's'),
          PurchaseRecord(date: DateTime(2026, 3, 20), price: 4500, store: 's'),
        ],
      );

      final service = ReportService.fromItems([sharedItem]);
      final feb = service.itemsOfMonth(DateTime(2026, 2, 1));
      final mar = service.itemsOfMonth(DateTime(2026, 3, 1));

      expect(feb.map((e) => e.id), ['shared']);
      expect(mar.map((e) => e.id), ['shared']);
    });
  });

  group('ReportService annual reports', () {
    test('aggregateYear returns 12 month buckets and annual total', () {
      final fixture = <ConsumableItem>[
        ConsumableItem(
          id: 'a',
          name: '세제',
          brand: 'x',
          category: '세탁',
          icon: Icons.circle,
          daysRemaining: 0,
          cycleDays: 30,
          progress: 0.5,
          purchaseHistory: [
            PurchaseRecord(
              date: DateTime(2026, 1, 12),
              price: 10000,
              store: 's',
            ),
            PurchaseRecord(
              date: DateTime(2026, 3, 15),
              price: 15000,
              store: 's',
            ),
            PurchaseRecord(
              date: DateTime(2025, 12, 30),
              price: 99999,
              store: 's',
            ),
          ],
        ),
        ConsumableItem(
          id: 'b',
          name: '필터',
          brand: 'x',
          category: '필터',
          icon: Icons.circle,
          daysRemaining: 0,
          cycleDays: 30,
          progress: 0.5,
          purchaseHistory: [
            PurchaseRecord(
              date: DateTime(2026, 3, 20),
              price: 8000,
              store: 's',
            ),
          ],
        ),
      ];

      final service = ReportService.fromItems(fixture);
      final yearly = service.aggregateYear(2026);

      expect(yearly.year, 2026);
      expect(yearly.months.length, 12);
      expect(yearly.months.first.month, DateTime(2026, 1, 1));
      expect(yearly.months.last.month, DateTime(2026, 12, 1));
      expect(yearly.totalAmount, 33000);
      expect(yearly.months[0].totalAmount, 10000);
      expect(yearly.months[2].totalAmount, 23000);
      expect(yearly.months[11].totalAmount, 0);
    });

    test('categoryBreakdownForYear aggregates only the selected year', () {
      final service = ReportService.fromItems(<ConsumableItem>[
        ConsumableItem(
          id: 'a',
          name: '세제',
          brand: 'x',
          category: '세탁',
          icon: Icons.circle,
          daysRemaining: 0,
          cycleDays: 30,
          progress: 0.5,
          purchaseHistory: [
            PurchaseRecord(
              date: DateTime(2026, 2, 1),
              price: 12000,
              store: 's',
            ),
            PurchaseRecord(
              date: DateTime(2025, 2, 1),
              price: 99000,
              store: 's',
            ),
          ],
        ),
        ConsumableItem(
          id: 'b',
          name: '필터',
          brand: 'x',
          category: '필터',
          icon: Icons.circle,
          daysRemaining: 0,
          cycleDays: 30,
          progress: 0.5,
          purchaseHistory: [
            PurchaseRecord(
              date: DateTime(2026, 2, 5),
              price: 18000,
              store: 's',
            ),
          ],
        ),
      ]);

      final breakdown = service.categoryBreakdownForYear(2026);

      expect(breakdown.length, 2);
      expect(breakdown[0].category, '필터');
      expect(breakdown[0].amount, 18000);
      expect(breakdown[1].category, '세탁');
      expect(breakdown[1].amount, 12000);
      expect(
        breakdown.fold<double>(0, (sum, item) => sum + item.ratio),
        closeTo(1.0, 0.001),
      );
    });
  });

  group('ReportService.latestMonthlyWithSpending', () {
    // 회귀: 현재 월 구매가 없으면 months.last가 0원 버킷이 되어 요약 화면이
    // "0원"으로 무너지는 문제(Codex adversarial review Finding 2). 이 메서드는
    // 지출이 있는 가장 최신 월을 대신 돌려줘야 한다.
    test('4월 구매가 없고 3월 구매가 있으면 3월 버킷을 반환한다', () {
      final fixture = <ConsumableItem>[
        ConsumableItem(
          id: 'a',
          name: '세제',
          brand: 'x',
          category: '세탁',
          icon: Icons.circle,
          daysRemaining: 0,
          cycleDays: 30,
          progress: 0.5,
          purchaseHistory: [
            PurchaseRecord(
              date: DateTime(2026, 3, 15),
              price: 15000,
              store: 's',
            ),
          ],
        ),
      ];

      final service = ReportService.fromItems(fixture);
      final latest = service.latestMonthlyWithSpending(
        now: DateTime(2026, 4, 15),
      );

      expect(latest, isNotNull);
      expect(latest!.month, DateTime(2026, 3, 1));
      expect(latest.totalAmount, 15000);
    });

    test('모든 버킷이 0원이면 null을 반환한다', () {
      final service = ReportService.fromItems(const []);
      final latest = service.latestMonthlyWithSpending(
        now: DateTime(2026, 4, 15),
      );
      expect(latest, isNull);
    });

    test('현재 월에 구매가 있으면 현재 월 버킷을 반환한다', () {
      final fixture = <ConsumableItem>[
        ConsumableItem(
          id: 'a',
          name: '주방',
          brand: 'x',
          category: '주방',
          icon: Icons.circle,
          daysRemaining: 0,
          cycleDays: 30,
          progress: 0.5,
          purchaseHistory: [
            PurchaseRecord(
              date: DateTime(2026, 4, 10),
              price: 5000,
              store: 's',
            ),
            PurchaseRecord(
              date: DateTime(2026, 3, 10),
              price: 7000,
              store: 's',
            ),
          ],
        ),
      ];

      final service = ReportService.fromItems(fixture);
      final latest = service.latestMonthlyWithSpending(
        now: DateTime(2026, 4, 15),
      );

      expect(latest!.month, DateTime(2026, 4, 1));
      expect(latest.totalAmount, 5000);
    });
  });

  group('ReportService 카테고리 스냅샷 의미론', () {
    // 현재 카테고리 스냅샷 귀속: PurchaseRecord 시점의 카테고리가 아니라
    // ConsumableItem.category(현재 값)가 기준. 따라서 동일 아이템의 모든
    // 구매 기록은, 해당 시점에 아이템이 무슨 카테고리였든, 현재 값으로 집계된다.
    // 이 테스트는 현재 카테고리를 '필터'로 둔 아이템의 Feb/Mar 구매 기록이
    // 모두 '필터' 버킷에 귀속되는지(즉, '위생'으로 흘러들지 않는지) 검증한다.
    test('현재 카테고리가 필터면, 과거 구매 기록도 필터로 귀속된다', () {
      final item = ConsumableItem(
        id: 'snapshot',
        name: '스냅샷 테스트',
        brand: 'x',
        category: '필터', // 현재 카테고리 — 원래 '위생'이었다는 외부 가정
        icon: Icons.circle,
        daysRemaining: 0,
        cycleDays: 30,
        progress: 0.5,
        purchaseHistory: [
          PurchaseRecord(date: DateTime(2026, 2, 10), price: 1000, store: 's'),
          PurchaseRecord(date: DateTime(2026, 3, 10), price: 2000, store: 's'),
        ],
      );

      final service = ReportService.fromItems([item]);
      final feb = service.categoryBreakdownFor(DateTime(2026, 2, 1));
      final mar = service.categoryBreakdownFor(DateTime(2026, 3, 1));

      expect(feb.length, 1);
      expect(feb.first.category, '필터');
      expect(feb.first.amount, 1000);

      expect(mar.length, 1);
      expect(mar.first.category, '필터');
      expect(mar.first.amount, 2000);
    });
  });

  group('ReportService period summaries', () {
    test('monthlySummary compares selected month with previous month', () {
      final service = ReportService.fromItems(<ConsumableItem>[
        ConsumableItem(
          id: 'a',
          name: '필터',
          brand: 'x',
          category: '가전/필터',
          icon: Icons.circle,
          daysRemaining: 10,
          cycleDays: 30,
          progress: 0.5,
          purchaseHistory: [
            PurchaseRecord(
              date: DateTime(2026, 4, 2),
              price: 30000,
              store: '쿠팡',
            ),
            PurchaseRecord(
              date: DateTime(2026, 3, 2),
              price: 20000,
              store: '쿠팡',
            ),
          ],
        ),
        ConsumableItem(
          id: 'b',
          name: '세제',
          brand: 'x',
          category: '주방/세제',
          icon: Icons.circle,
          daysRemaining: 20,
          cycleDays: 30,
          progress: 0.4,
          purchaseHistory: [
            PurchaseRecord(
              date: DateTime(2026, 4, 8),
              price: 5000,
              store: '이마트',
            ),
          ],
        ),
      ]);

      final summary = service.monthlySummary(DateTime(2026, 4, 1));

      expect(summary.totalAmount, 35000);
      expect(summary.previousAmount, 20000);
      expect(summary.deltaAmount, 15000);
      expect(summary.purchaseCount, 2);
      expect(summary.topCategory, '가전/필터');
      expect(summary.topCategoryAmount, 30000);
    });

    test('yearlySummary compares selected year with previous year', () {
      final service = ReportService.fromItems(<ConsumableItem>[
        ConsumableItem(
          id: 'a',
          name: '필터',
          brand: 'x',
          category: '가전/필터',
          icon: Icons.circle,
          daysRemaining: 10,
          cycleDays: 30,
          progress: 0.5,
          purchaseHistory: [
            PurchaseRecord(
              date: DateTime(2026, 2, 2),
              price: 30000,
              store: '쿠팡',
            ),
            PurchaseRecord(
              date: DateTime(2025, 2, 2),
              price: 12000,
              store: '쿠팡',
            ),
          ],
        ),
      ]);

      final summary = service.yearlySummary(2026);

      expect(summary.totalAmount, 30000);
      expect(summary.previousAmount, 12000);
      expect(summary.deltaAmount, 18000);
      expect(summary.purchaseCount, 1);
      expect(summary.topCategory, '가전/필터');
    });
  });

  group('ReportService refillForecast', () {
    test('groups upcoming items into 30, 60, and 90 day forecast windows', () {
      final service = ReportService.fromItems(<ConsumableItem>[
        ConsumableItem(
          id: 'soon',
          name: '화장지',
          brand: '코디',
          category: '욕실/위생',
          icon: Icons.circle,
          daysRemaining: 12,
          cycleDays: 30,
          progress: 0.6,
          purchaseHistory: [
            PurchaseRecord(
              date: DateTime(2026, 4, 1),
              price: 15000,
              store: '쿠팡',
            ),
          ],
        ),
        ConsumableItem(
          id: 'later',
          name: '필터',
          brand: '코웨이',
          category: '가전/필터',
          icon: Icons.circle,
          daysRemaining: 44,
          cycleDays: 90,
          progress: 0.5,
          purchaseHistory: [
            PurchaseRecord(
              date: DateTime(2026, 2, 1),
              price: 35000,
              store: '코웨이몰',
            ),
          ],
        ),
        ConsumableItem(
          id: 'far',
          name: '샴푸',
          brand: '케라시스',
          category: '헤어/바디',
          icon: Icons.circle,
          daysRemaining: 110,
          cycleDays: 120,
          progress: 0.1,
          purchaseHistory: [
            PurchaseRecord(
              date: DateTime(2026, 1, 1),
              price: 9000,
              store: '올리브영',
            ),
          ],
        ),
      ]);

      final forecast = service.refillForecast();

      expect(forecast.next30DaysAmount, 15000);
      expect(forecast.next60DaysAmount, 50000);
      expect(forecast.next90DaysAmount, 50000);
      expect(forecast.items.map((e) => e.item.id), ['soon', 'later']);
    });
  });

  group('ReportService priceMovements', () {
    test(
      'returns items with recent price changes sorted by absolute delta',
      () {
        final service = ReportService.fromItems(<ConsumableItem>[
          ConsumableItem(
            id: 'up',
            name: '주방 세제',
            brand: '자연퐁',
            category: '주방/세제',
            icon: Icons.circle,
            daysRemaining: 10,
            cycleDays: 30,
            progress: 0.6,
            purchaseHistory: [
              PurchaseRecord(
                date: DateTime(2026, 4, 1),
                price: 6000,
                store: '쿠팡',
              ),
              PurchaseRecord(
                date: DateTime(2026, 3, 1),
                price: 4500,
                store: '이마트',
              ),
            ],
          ),
          ConsumableItem(
            id: 'same',
            name: '샴푸',
            brand: '케라시스',
            category: '헤어/바디',
            icon: Icons.circle,
            daysRemaining: 20,
            cycleDays: 60,
            progress: 0.4,
            purchaseHistory: [
              PurchaseRecord(
                date: DateTime(2026, 4, 1),
                price: 9000,
                store: '올리브영',
              ),
              PurchaseRecord(
                date: DateTime(2026, 3, 1),
                price: 9000,
                store: '쿠팡',
              ),
            ],
          ),
        ]);

        final movements = service.priceMovements(limit: 3);

        expect(movements.length, 1);
        expect(movements.first.item.id, 'up');
        expect(movements.first.currentPrice, 6000);
        expect(movements.first.previousPrice, 4500);
        expect(movements.first.deltaAmount, 1500);
        expect(movements.first.deltaRatio, closeTo(0.333, 0.001));
      },
    );
  });

  group('ReportService smartInsights', () {
    test(
      'creates deterministic insights from summary, forecast, and price movement',
      () {
        final service = ReportService.fromItems(<ConsumableItem>[
          ConsumableItem(
            id: 'filter',
            name: '정수기 필터',
            brand: '코웨이',
            category: '가전/필터',
            icon: Icons.circle,
            daysRemaining: 7,
            cycleDays: 90,
            progress: 0.9,
            purchaseHistory: [
              PurchaseRecord(
                date: DateTime(2026, 4, 1),
                price: 35000,
                store: '코웨이몰',
              ),
              PurchaseRecord(
                date: DateTime(2026, 3, 1),
                price: 30000,
                store: '쿠팡',
              ),
            ],
          ),
        ]);

        final insights = service.smartInsights(month: DateTime(2026, 4, 1));

        expect(insights, isNotEmpty);
        expect(insights.first.title, isNotEmpty);
        expect(insights.map((e) => e.kind), contains(ReportInsightKind.refill));
      },
    );
  });

  group('ReportService category comparisons', () {
    test(
      'categoryComparisonForMonth compares selected month to previous month',
      () {
        final service = ReportService.fromItems(<ConsumableItem>[
          ConsumableItem(
            id: 'filter',
            name: '정수기 필터',
            brand: '코웨이',
            category: '가전/필터',
            icon: Icons.circle,
            daysRemaining: 7,
            cycleDays: 90,
            progress: 0.9,
            purchaseHistory: [
              PurchaseRecord(
                date: DateTime(2026, 4, 1),
                price: 30000,
                store: '코웨이몰',
              ),
              PurchaseRecord(
                date: DateTime(2026, 3, 1),
                price: 10000,
                store: '쿠팡',
              ),
            ],
          ),
        ]);

        final rows = service.categoryComparisonForMonth(DateTime(2026, 4, 1));

        expect(rows.first.category, '가전/필터');
        expect(rows.first.amount, 30000);
        expect(rows.first.previousAmount, 10000);
        expect(rows.first.deltaAmount, 20000);
        expect(rows.first.purchaseCount, 1);
      },
    );

    test(
      'categoryComparisonForYear compares selected year to previous year',
      () {
        final service = ReportService.fromItems(<ConsumableItem>[
          ConsumableItem(
            id: 'filter',
            name: '정수기 필터',
            brand: '코웨이',
            category: '가전/필터',
            icon: Icons.circle,
            daysRemaining: 7,
            cycleDays: 90,
            progress: 0.9,
            purchaseHistory: [
              PurchaseRecord(
                date: DateTime(2026, 4, 1),
                price: 30000,
                store: '코웨이몰',
              ),
              PurchaseRecord(
                date: DateTime(2025, 4, 1),
                price: 12000,
                store: '쿠팡',
              ),
            ],
          ),
        ]);

        final rows = service.categoryComparisonForYear(2026);

        expect(rows.first.category, '가전/필터');
        expect(rows.first.amount, 30000);
        expect(rows.first.previousAmount, 12000);
        expect(rows.first.deltaAmount, 18000);
        expect(rows.first.purchaseCount, 1);
      },
    );
  });
}
