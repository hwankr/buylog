import '../models/item.dart';

/// 월간 지출 리포트 집계 서비스.
///
/// 주의(Supabase 호환성, Issue #1):
///   현재 구현은 **동기 in-memory**다. 향후 Supabase 연동 시 async 변형이
///   추가될 수 있으며, 이때 본 클래스의 시그니처는 breaking change를
///   동반할 수 있다. 소비자는 repository 주입 형태로 리팩토링될 가능성을
///   전제로 호출부를 얇게 유지할 것.
///
/// 카테고리 의미론 (스냅샷):
///   과거 `PurchaseRecord` 시점의 카테고리는 별도 저장되지 않으므로,
///   모든 집계는 **현재 `ConsumableItem.category`로 스냅샷 귀속**된다.
///   즉, 아이템의 카테고리가 바뀌면 과거 지출도 새 카테고리로 재귀속된다.
class ReportService {
  ReportService({required this.source});

  factory ReportService.fromItems(List<ConsumableItem> items) =>
      ReportService(source: items);

  final List<ConsumableItem> source;

  static DateTime _monthKey(DateTime d) => DateTime(d.year, d.month, 1);

  /// 최근 N개월 집계(기본 6). 오래된 → 최신 순. `now`는 테스트 주입용.
  List<MonthlySpending> aggregateRecentMonths({int months = 6, DateTime? now}) {
    final latest = _monthKey(now ?? DateTime.now());

    final buckets = <DateTime>[
      for (var i = months - 1; i >= 0; i--)
        DateTime(latest.year, latest.month - i, 1),
    ];

    return buckets.map((bucket) {
      var total = 0;
      final byCategory = <String, int>{};
      final itemsInBucket = <ConsumableItem>[];

      for (final item in source) {
        var matched = false;
        for (final pr in item.purchaseHistory) {
          if (_monthKey(pr.date) == bucket) {
            total += pr.price;
            byCategory[item.category] =
                (byCategory[item.category] ?? 0) + pr.price;
            matched = true;
          }
        }
        if (matched) itemsInBucket.add(item);
      }

      return MonthlySpending(
        month: bucket,
        totalAmount: total,
        byCategory: byCategory,
        items: itemsInBucket,
      );
    }).toList();
  }

  /// 선택 연도의 1월→12월 지출 집계.
  YearlySpending aggregateYear(int year) {
    final months = <MonthlySpending>[
      for (var month = 1; month <= 12; month++)
        _aggregateMonth(DateTime(year, month, 1)),
    ];

    return YearlySpending(year: year, months: months);
  }

  /// 특정 월의 카테고리 breakdown (ratio 포함). 데이터 없으면 빈 리스트.
  List<CategoryBreakdown> categoryBreakdownFor(DateTime month) {
    final key = _monthKey(month);
    var total = 0;
    final byCategory = <String, int>{};

    for (final item in source) {
      for (final pr in item.purchaseHistory) {
        if (_monthKey(pr.date) == key) {
          total += pr.price;
          byCategory[item.category] =
              (byCategory[item.category] ?? 0) + pr.price;
        }
      }
    }

    if (total == 0) return const <CategoryBreakdown>[];

    return byCategory.entries
        .map(
          (e) => CategoryBreakdown(
            category: e.key,
            amount: e.value,
            ratio: e.value / total,
          ),
        )
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
  }

  /// 선택 연도 전체의 카테고리 breakdown.
  List<CategoryBreakdown> categoryBreakdownForYear(int year) {
    var total = 0;
    final byCategory = <String, int>{};

    for (final item in source) {
      for (final pr in item.purchaseHistory) {
        if (pr.date.year == year) {
          total += pr.price;
          byCategory[item.category] =
              (byCategory[item.category] ?? 0) + pr.price;
        }
      }
    }

    if (total == 0) return const <CategoryBreakdown>[];

    return byCategory.entries
        .map(
          (e) => CategoryBreakdown(
            category: e.key,
            amount: e.value,
            ratio: e.value / total,
          ),
        )
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
  }

  /// 최근 N개월 창에서 지출이 있는 가장 최신 월. 모두 0원이면 `null`.
  ///
  /// 현재 월에 아직 구매가 없으면 `aggregateRecentMonths().last`는 0원 버킷이
  /// 되어 요약 화면이 "0원"으로 깨진다. 화면은 이 값으로 "의미 있는 최신 월"을
  /// 고르고, null이면 빈 상태 UI로 fallback한다.
  MonthlySpending? latestMonthlyWithSpending({int months = 6, DateTime? now}) {
    final buckets = aggregateRecentMonths(months: months, now: now);
    for (var i = buckets.length - 1; i >= 0; i--) {
      if (buckets[i].totalAmount > 0) return buckets[i];
    }
    return null;
  }

  /// 특정 월의 구매 이력을 가진 아이템들.
  List<ConsumableItem> itemsOfMonth(DateTime month) {
    final key = _monthKey(month);
    return source
        .where(
          (item) => item.purchaseHistory.any((pr) => _monthKey(pr.date) == key),
        )
        .toList();
  }

  ReportPeriodSummary monthlySummary(DateTime month) {
    final current = _aggregateMonth(_monthKey(month));
    final previous = _aggregateMonth(DateTime(month.year, month.month - 1, 1));

    return _summaryFrom(
      totalAmount: current.totalAmount,
      previousAmount: previous.totalAmount,
      byCategory: current.byCategory,
      purchaseCount: _purchaseCountForMonth(month),
    );
  }

  ReportPeriodSummary yearlySummary(int year) {
    final current = aggregateYear(year);
    final previous = aggregateYear(year - 1);
    final byCategory = <String, int>{};
    var purchaseCount = 0;

    for (final item in source) {
      for (final purchase in item.purchaseHistory) {
        if (purchase.date.year != year) continue;
        purchaseCount++;
        byCategory[item.category] =
            (byCategory[item.category] ?? 0) + purchase.price;
      }
    }

    return _summaryFrom(
      totalAmount: current.totalAmount,
      previousAmount: previous.totalAmount,
      byCategory: byCategory,
      purchaseCount: purchaseCount,
    );
  }

  RefillForecast refillForecast() {
    final items =
        source
            .where((item) => item.purchaseHistory.isNotEmpty)
            .map(
              (item) => RefillForecastItem(
                item: item,
                expectedPrice: item.purchaseHistory.first.price,
                daysUntilRefill: item.daysRemaining < 0
                    ? 0
                    : item.daysRemaining,
              ),
            )
            .where((entry) => entry.daysUntilRefill <= 90)
            .toList()
          ..sort((a, b) => a.daysUntilRefill.compareTo(b.daysUntilRefill));

    int sumUntil(int days) => items
        .where((entry) => entry.daysUntilRefill <= days)
        .fold<int>(0, (sum, entry) => sum + entry.expectedPrice);

    return RefillForecast(
      next30DaysAmount: sumUntil(30),
      next60DaysAmount: sumUntil(60),
      next90DaysAmount: sumUntil(90),
      items: items,
    );
  }

  List<PriceMovement> priceMovements({int limit = 5}) {
    final movements = <PriceMovement>[];

    for (final item in source) {
      if (item.purchaseHistory.length < 2) continue;
      final sorted = List<PurchaseRecord>.from(item.purchaseHistory)
        ..sort((a, b) => b.date.compareTo(a.date));
      final current = sorted[0];
      final previous = sorted[1];
      if (current.price == previous.price) continue;

      movements.add(
        PriceMovement(
          item: item,
          currentPrice: current.price,
          previousPrice: previous.price,
          currentStore: current.store,
          previousStore: previous.store,
        ),
      );
    }

    movements.sort(
      (a, b) => b.deltaAmount.abs().compareTo(a.deltaAmount.abs()),
    );
    return movements.take(limit).toList();
  }

  List<ReportInsight> smartInsights({required DateTime month}) {
    final summary = monthlySummary(month);
    final forecast = refillForecast();
    final movements = priceMovements(limit: 1);
    final insights = <ReportInsight>[];

    if (summary.deltaAmount != 0 && summary.hasPrevious) {
      final direction = summary.deltaAmount > 0 ? '증가' : '감소';
      insights.add(
        ReportInsight(
          kind: ReportInsightKind.spending,
          title: '지출 흐름 변화',
          body: '전월보다 ${summary.deltaAmount.abs()}원 $direction했어요.',
          priority: 20,
        ),
      );
    }

    if (forecast.items.isNotEmpty) {
      final next30Count = forecast.items
          .where((entry) => entry.daysUntilRefill <= 30)
          .length;
      insights.add(
        ReportInsight(
          kind: ReportInsightKind.refill,
          title: '다가오는 재구매',
          body:
              '30일 안에 $next30Count개 품목, 예상 ${forecast.next30DaysAmount}원이 필요해요.',
          priority: 30,
        ),
      );
    }

    if (movements.isNotEmpty) {
      final movement = movements.first;
      final direction = movement.deltaAmount > 0 ? '올랐어요' : '내렸어요';
      insights.add(
        ReportInsight(
          kind: ReportInsightKind.price,
          title: '가격 변동 감지',
          body:
              '${movement.item.name} 가격이 직전 구매보다 ${movement.deltaAmount.abs()}원 $direction.',
          priority: 10,
        ),
      );
    }

    insights.sort((a, b) => b.priority.compareTo(a.priority));
    return insights.take(3).toList();
  }

  List<CategoryComparison> categoryComparisonForMonth(DateTime month) {
    final currentKey = _monthKey(month);
    final previousKey = DateTime(month.year, month.month - 1, 1);
    return _categoryComparison(
      includeCurrent: (date) => _monthKey(date) == currentKey,
      includePrevious: (date) => _monthKey(date) == previousKey,
    );
  }

  List<CategoryComparison> categoryComparisonForYear(int year) {
    return _categoryComparison(
      includeCurrent: (date) => date.year == year,
      includePrevious: (date) => date.year == year - 1,
    );
  }

  MonthlySpending _aggregateMonth(DateTime bucket) {
    var total = 0;
    final byCategory = <String, int>{};
    final itemsInBucket = <ConsumableItem>[];

    for (final item in source) {
      var matched = false;
      for (final pr in item.purchaseHistory) {
        if (_monthKey(pr.date) == bucket) {
          total += pr.price;
          byCategory[item.category] =
              (byCategory[item.category] ?? 0) + pr.price;
          matched = true;
        }
      }
      if (matched) itemsInBucket.add(item);
    }

    return MonthlySpending(
      month: bucket,
      totalAmount: total,
      byCategory: byCategory,
      items: itemsInBucket,
    );
  }

  ReportPeriodSummary _summaryFrom({
    required int totalAmount,
    required int previousAmount,
    required Map<String, int> byCategory,
    required int purchaseCount,
  }) {
    final top = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ReportPeriodSummary(
      totalAmount: totalAmount,
      previousAmount: previousAmount,
      deltaAmount: totalAmount - previousAmount,
      purchaseCount: purchaseCount,
      topCategory: top.isEmpty ? null : top.first.key,
      topCategoryAmount: top.isEmpty ? 0 : top.first.value,
    );
  }

  int _purchaseCountForMonth(DateTime month) {
    final key = _monthKey(month);
    var count = 0;
    for (final item in source) {
      for (final purchase in item.purchaseHistory) {
        if (_monthKey(purchase.date) == key) count++;
      }
    }
    return count;
  }

  List<CategoryComparison> _categoryComparison({
    required bool Function(DateTime date) includeCurrent,
    required bool Function(DateTime date) includePrevious,
  }) {
    var total = 0;
    final current = <String, int>{};
    final previous = <String, int>{};
    final purchaseCounts = <String, int>{};

    for (final item in source) {
      for (final purchase in item.purchaseHistory) {
        if (includeCurrent(purchase.date)) {
          total += purchase.price;
          current[item.category] =
              (current[item.category] ?? 0) + purchase.price;
          purchaseCounts[item.category] =
              (purchaseCounts[item.category] ?? 0) + 1;
        }
        if (includePrevious(purchase.date)) {
          previous[item.category] =
              (previous[item.category] ?? 0) + purchase.price;
        }
      }
    }

    if (total == 0) return const <CategoryComparison>[];

    return current.entries
        .map(
          (entry) => CategoryComparison(
            category: entry.key,
            amount: entry.value,
            previousAmount: previous[entry.key] ?? 0,
            purchaseCount: purchaseCounts[entry.key] ?? 0,
            ratio: entry.value / total,
          ),
        )
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
  }
}

class MonthlySpending {
  final DateTime month; // 해당 월의 1일 (local time, year+month만 의미 있음)
  final int totalAmount; // 해당 월 총 지출(원)
  final Map<String, int> byCategory; // 카테고리명 → 합계(원)
  final List<ConsumableItem> items; // 해당 월 구매 이력을 가진 아이템

  const MonthlySpending({
    required this.month,
    required this.totalAmount,
    required this.byCategory,
    required this.items,
  });
}

class YearlySpending {
  final int year;
  final List<MonthlySpending> months;

  const YearlySpending({required this.year, required this.months});

  int get totalAmount =>
      months.fold<int>(0, (sum, month) => sum + month.totalAmount);
}

class CategoryBreakdown {
  final String category;
  final int amount;
  final double ratio; // 0.0~1.0, 합 = 1.0 ± 0.001

  const CategoryBreakdown({
    required this.category,
    required this.amount,
    required this.ratio,
  });
}

class ReportPeriodSummary {
  final int totalAmount;
  final int previousAmount;
  final int deltaAmount;
  final int purchaseCount;
  final String? topCategory;
  final int topCategoryAmount;

  const ReportPeriodSummary({
    required this.totalAmount,
    required this.previousAmount,
    required this.deltaAmount,
    required this.purchaseCount,
    required this.topCategory,
    required this.topCategoryAmount,
  });

  bool get hasPrevious => previousAmount > 0;

  double? get deltaRatio {
    if (previousAmount == 0) return null;
    return deltaAmount / previousAmount;
  }
}

class RefillForecast {
  final int next30DaysAmount;
  final int next60DaysAmount;
  final int next90DaysAmount;
  final List<RefillForecastItem> items;

  const RefillForecast({
    required this.next30DaysAmount,
    required this.next60DaysAmount,
    required this.next90DaysAmount,
    required this.items,
  });
}

class RefillForecastItem {
  final ConsumableItem item;
  final int expectedPrice;
  final int daysUntilRefill;

  const RefillForecastItem({
    required this.item,
    required this.expectedPrice,
    required this.daysUntilRefill,
  });
}

class PriceMovement {
  final ConsumableItem item;
  final int currentPrice;
  final int previousPrice;
  final String currentStore;
  final String previousStore;

  const PriceMovement({
    required this.item,
    required this.currentPrice,
    required this.previousPrice,
    required this.currentStore,
    required this.previousStore,
  });

  int get deltaAmount => currentPrice - previousPrice;

  double get deltaRatio => previousPrice == 0 ? 0 : deltaAmount / previousPrice;
}

enum ReportInsightKind { spending, refill, price }

class ReportInsight {
  final ReportInsightKind kind;
  final String title;
  final String body;
  final int priority;

  const ReportInsight({
    required this.kind,
    required this.title,
    required this.body,
    required this.priority,
  });
}

class CategoryComparison {
  final String category;
  final int amount;
  final int previousAmount;
  final int purchaseCount;
  final double ratio;

  const CategoryComparison({
    required this.category,
    required this.amount,
    required this.previousAmount,
    required this.purchaseCount,
    required this.ratio,
  });

  int get deltaAmount => amount - previousAmount;
}
