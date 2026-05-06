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
