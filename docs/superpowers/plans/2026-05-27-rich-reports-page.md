# Rich Reports Page Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 리포트 페이지를 단순 지출 차트에서 buylog만의 강점인 소모품 교체 주기, 재구매 예측, 가격 변동, 카테고리 소비 패턴을 한눈에 보여주는 분석 화면으로 강화한다.

**Architecture:** 집계/판단 로직은 `ReportService`와 전용 값 객체에 둔다. `ReportsScreen`은 상태와 섹션 배치만 담당하고, UI는 `lib/widgets/reports/`의 작은 위젯으로 분리한다. 기존 `fl_chart`, `AppColors`, `SampleData` 기반을 유지하고 신규 패키지는 추가하지 않는다.

**Tech Stack:** Flutter, Dart, Material 3, `fl_chart`, `flutter_test`

---

## Product Direction

현재 리포트는 월간/연간 합계, 카테고리 도넛, 막대 차트, 선택 월 상세 내역이 중심이다. 차별화 방향은 "얼마를 썼는가"보다 "앞으로 어떤 소모품 비용이 다가오고, 어떤 품목/카테고리가 소비 패턴을 바꾸고 있는가"를 보여주는 것이다.

이번 계획의 핵심 섹션은 다음 5개다.

1. **Report Hero**: 선택 기간 총액, 전월/전년 대비 증감, 구매 건수, 최상위 카테고리를 한 화면 상단에서 보여준다.
2. **Smart Insight Strip**: 규칙 기반 인사이트 2~3개를 카드로 표시한다. 예: "이번 달 필터 지출이 전월보다 34,900원 증가", "30일 안에 4개 품목 재구매 예상".
3. **Upcoming Refill Forecast**: `daysRemaining`과 최근 구매가로 30/60/90일 예상 지출을 계산해 buylog의 소모품 관리 강점을 드러낸다.
4. **Price Movement Watch**: 같은 품목의 최근 구매가와 직전 구매가를 비교해 가격 상승/하락 품목을 보여준다.
5. **Enhanced Category Breakdown**: 기존 카테고리 목록에 전월 대비 증감, 품목 수, 구매 건수를 추가한다.

## File Structure

- Modify `lib/services/report_service.dart`
  - 리포트 전용 값 객체와 집계 메서드 추가.
  - 기간 비교, 인사이트, 교체 예정 비용, 가격 변동 계산을 담당.
- Modify `test/services/report_service_test.dart`
  - 새 비즈니스 로직의 고정 fixture 기반 단위 테스트 추가.
- Modify `lib/screens/reports_screen.dart`
  - 섹션 위젯 조립과 월/연 상태 전달만 담당하도록 정리.
  - `_formatPrice` 중복은 새 유틸로 제거한다.
- Create `lib/utils/price_format.dart`
  - `formatPrice(int price)` 공용화.
- Modify `lib/widgets/reports/month_filter_list_view.dart`
  - 새 가격 포맷 유틸 사용.
- Create `lib/widgets/reports/report_hero_card.dart`
  - 기간 총액, 증감, 구매 건수, top category KPI 표시.
- Create `lib/widgets/reports/report_insight_strip.dart`
  - 규칙 기반 인사이트 카드 가로 스크롤/랩 표시.
- Create `lib/widgets/reports/refill_forecast_card.dart`
  - 30/60/90일 예상 교체 비용과 예정 품목 표시.
- Create `lib/widgets/reports/price_movement_list.dart`
  - 최근 가격 변동 품목 리스트 표시.
- Create `lib/widgets/reports/enhanced_category_breakdown_list.dart`
  - 기존 카테고리 목록을 별도 위젯으로 분리하고 증감/건수 표시.
- Modify `test/screens/reports_screen_year_view_test.dart`
  - 새 섹션이 월간/연간 모드에서 적절히 보이는지 검증.
- Modify `test/screens/reports_screen_month_filter_test.dart`
  - 기존 월 선택 상세 내역 회귀 테스트 유지.
- Create `test/widgets/reports/report_hero_card_test.dart`
- Create `test/widgets/reports/report_insight_strip_test.dart`
- Create `test/widgets/reports/refill_forecast_card_test.dart`
- Create `test/widgets/reports/price_movement_list_test.dart`

---

### Task 1: Shared Price Formatter

**Files:**
- Create: `lib/utils/price_format.dart`
- Modify: `lib/screens/reports_screen.dart`
- Modify: `lib/widgets/reports/month_filter_list_view.dart`
- Test: existing screen/widget tests

- [ ] **Step 1: Create the formatter**

```dart
String formatPrice(int price) {
  final sign = price < 0 ? '-' : '';
  final digits = price.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '$sign${buffer}원';
}
```

- [ ] **Step 2: Replace local `_formatPrice`**

In `reports_screen.dart` and `month_filter_list_view.dart`, import:

```dart
import '../utils/price_format.dart';
```

or, from widgets:

```dart
import '../../utils/price_format.dart';
```

Then replace `_formatPrice(value)` with `formatPrice(value)` and delete the local methods.

- [ ] **Step 3: Run regression tests**

Run:

```bash
flutter test test/widgets/reports/month_filter_list_view_test.dart test/screens/reports_screen_month_filter_test.dart
```

Expected: PASS. The `"12,500원"` assertion must still pass.

- [ ] **Step 4: Commit**

```bash
git add lib/utils/price_format.dart lib/screens/reports_screen.dart lib/widgets/reports/month_filter_list_view.dart
git commit -m "refactor: share report price formatter"
```

---

### Task 2: Report Summary Metrics

**Files:**
- Modify: `lib/services/report_service.dart`
- Modify: `test/services/report_service_test.dart`

- [ ] **Step 1: Add failing tests**

Add tests that cover monthly comparison, yearly comparison, purchase count, top category, and empty data:

```dart
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
          PurchaseRecord(date: DateTime(2026, 4, 2), price: 30000, store: '쿠팡'),
          PurchaseRecord(date: DateTime(2026, 3, 2), price: 20000, store: '쿠팡'),
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
          PurchaseRecord(date: DateTime(2026, 4, 8), price: 5000, store: '이마트'),
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
          PurchaseRecord(date: DateTime(2026, 2, 2), price: 30000, store: '쿠팡'),
          PurchaseRecord(date: DateTime(2025, 2, 2), price: 12000, store: '쿠팡'),
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
```

- [ ] **Step 2: Run tests to verify failure**

Run:

```bash
flutter test test/services/report_service_test.dart
```

Expected: FAIL with missing `monthlySummary`, `yearlySummary`, and `ReportPeriodSummary`.

- [ ] **Step 3: Implement values and methods**

Add to `report_service.dart`:

```dart
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
```

Add methods to `ReportService`:

```dart
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
```

- [ ] **Step 4: Run tests**

Run:

```bash
flutter test test/services/report_service_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/services/report_service.dart test/services/report_service_test.dart
git commit -m "feat: add report period summaries"
```

---

### Task 3: Refill Forecast Logic

**Files:**
- Modify: `lib/services/report_service.dart`
- Modify: `test/services/report_service_test.dart`

- [ ] **Step 1: Add failing tests**

```dart
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
          PurchaseRecord(date: DateTime(2026, 4, 1), price: 15000, store: '쿠팡'),
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
          PurchaseRecord(date: DateTime(2026, 2, 1), price: 35000, store: '코웨이몰'),
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
          PurchaseRecord(date: DateTime(2026, 1, 1), price: 9000, store: '올리브영'),
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
```

- [ ] **Step 2: Run tests to verify failure**

Run:

```bash
flutter test test/services/report_service_test.dart
```

Expected: FAIL with missing `refillForecast`.

- [ ] **Step 3: Implement forecast values**

Add:

```dart
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
```

Add to `ReportService`:

```dart
RefillForecast refillForecast() {
  final items = source
      .where((item) => item.purchaseHistory.isNotEmpty)
      .map(
        (item) => RefillForecastItem(
          item: item,
          expectedPrice: item.purchaseHistory.first.price,
          daysUntilRefill: item.daysRemaining < 0 ? 0 : item.daysRemaining,
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
```

- [ ] **Step 4: Run tests**

Run:

```bash
flutter test test/services/report_service_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/services/report_service.dart test/services/report_service_test.dart
git commit -m "feat: add refill forecast metrics"
```

---

### Task 4: Price Movement Logic

**Files:**
- Modify: `lib/services/report_service.dart`
- Modify: `test/services/report_service_test.dart`

- [ ] **Step 1: Add failing tests**

```dart
group('ReportService priceMovements', () {
  test('returns items with recent price changes sorted by absolute delta', () {
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
          PurchaseRecord(date: DateTime(2026, 4, 1), price: 6000, store: '쿠팡'),
          PurchaseRecord(date: DateTime(2026, 3, 1), price: 4500, store: '이마트'),
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
          PurchaseRecord(date: DateTime(2026, 4, 1), price: 9000, store: '올리브영'),
          PurchaseRecord(date: DateTime(2026, 3, 1), price: 9000, store: '쿠팡'),
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
  });
});
```

- [ ] **Step 2: Run tests to verify failure**

Run:

```bash
flutter test test/services/report_service_test.dart
```

Expected: FAIL with missing `priceMovements`.

- [ ] **Step 3: Implement movement values**

Add:

```dart
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
```

Add to `ReportService`:

```dart
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
```

- [ ] **Step 4: Run tests**

Run:

```bash
flutter test test/services/report_service_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/services/report_service.dart test/services/report_service_test.dart
git commit -m "feat: add report price movement metrics"
```

---

### Task 5: Insight Rules

**Files:**
- Modify: `lib/services/report_service.dart`
- Modify: `test/services/report_service_test.dart`

- [ ] **Step 1: Add failing tests**

```dart
group('ReportService smartInsights', () {
  test('creates deterministic insights from summary, forecast, and price movement', () {
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
          PurchaseRecord(date: DateTime(2026, 4, 1), price: 35000, store: '코웨이몰'),
          PurchaseRecord(date: DateTime(2026, 3, 1), price: 30000, store: '쿠팡'),
        ],
      ),
    ]);

    final insights = service.smartInsights(month: DateTime(2026, 4, 1));

    expect(insights, isNotEmpty);
    expect(insights.first.title, isNotEmpty);
    expect(insights.map((e) => e.kind), contains(ReportInsightKind.refill));
  });
});
```

- [ ] **Step 2: Run tests to verify failure**

Run:

```bash
flutter test test/services/report_service_test.dart
```

Expected: FAIL with missing `smartInsights`.

- [ ] **Step 3: Implement insights**

Add:

```dart
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
```

Add to `ReportService`:

```dart
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
    insights.add(
      ReportInsight(
        kind: ReportInsightKind.refill,
        title: '다가오는 재구매',
        body:
            '30일 안에 ${forecast.items.where((e) => e.daysUntilRefill <= 30).length}개 품목, 예상 ${forecast.next30DaysAmount}원이 필요해요.',
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
        body: '${movement.item.name} 가격이 직전 구매보다 ${movement.deltaAmount.abs()}원 $direction.',
        priority: 10,
      ),
    );
  }

  insights.sort((a, b) => b.priority.compareTo(a.priority));
  return insights.take(3).toList();
}
```

- [ ] **Step 4: Run tests**

Run:

```bash
flutter test test/services/report_service_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/services/report_service.dart test/services/report_service_test.dart
git commit -m "feat: add smart report insights"
```

---

### Task 6: Report Hero UI

**Files:**
- Create: `lib/widgets/reports/report_hero_card.dart`
- Create: `test/widgets/reports/report_hero_card_test.dart`

- [ ] **Step 1: Add widget tests**

```dart
testWidgets('ReportHeroCard renders amount, delta, purchase count, and top category', (tester) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: Scaffold(
        body: ReportHeroCard(
          title: '4월 리포트',
          summary: ReportPeriodSummary(
            totalAmount: 35000,
            previousAmount: 20000,
            deltaAmount: 15000,
            purchaseCount: 2,
            topCategory: '가전/필터',
            topCategoryAmount: 30000,
          ),
        ),
      ),
    ),
  );

  expect(find.text('4월 리포트'), findsOneWidget);
  expect(find.text('35,000원'), findsOneWidget);
  expect(find.textContaining('15,000원'), findsOneWidget);
  expect(find.text('구매 2건'), findsOneWidget);
  expect(find.text('가전/필터'), findsOneWidget);
});
```

- [ ] **Step 2: Run tests to verify failure**

Run:

```bash
flutter test test/widgets/reports/report_hero_card_test.dart
```

Expected: FAIL because widget does not exist.

- [ ] **Step 3: Implement widget**

Use `Card`-like `Container`, 16 px radius to match current reports cards. Include:

```dart
class ReportHeroCard extends StatelessWidget {
  const ReportHeroCard({
    super.key,
    required this.title,
    required this.summary,
  });

  final String title;
  final ReportPeriodSummary summary;

  @override
  Widget build(BuildContext context) {
    final deltaLabel = summary.deltaAmount == 0
        ? '전 기간과 동일'
        : '전 기간 대비 ${formatPrice(summary.deltaAmount.abs())} ${summary.deltaAmount > 0 ? '증가' : '감소'}';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            formatPrice(summary.totalAmount),
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetricChip(icon: Icons.trending_up_outlined, label: deltaLabel),
              _MetricChip(icon: Icons.receipt_long_outlined, label: '구매 ${summary.purchaseCount}건'),
              _MetricChip(icon: Icons.category_outlined, label: summary.topCategory ?? '카테고리 없음'),
            ],
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests**

Run:

```bash
flutter test test/widgets/reports/report_hero_card_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/reports/report_hero_card.dart test/widgets/reports/report_hero_card_test.dart
git commit -m "feat: add report hero card"
```

---

### Task 7: Insight, Forecast, and Price Movement Widgets

**Files:**
- Create: `lib/widgets/reports/report_insight_strip.dart`
- Create: `lib/widgets/reports/refill_forecast_card.dart`
- Create: `lib/widgets/reports/price_movement_list.dart`
- Create: matching widget tests

- [ ] **Step 1: Write widget tests**

Assert visible labels:

```dart
expect(find.text('다가오는 재구매'), findsOneWidget);
expect(find.text('30일'), findsOneWidget);
expect(find.text('가격 변동'), findsOneWidget);
```

Use fixed `ReportInsight`, `RefillForecast`, and `PriceMovement` fixtures.

- [ ] **Step 2: Implement `ReportInsightStrip`**

Render up to three compact cards with icon by `ReportInsightKind`:

```dart
IconData _iconFor(ReportInsightKind kind) {
  return switch (kind) {
    ReportInsightKind.spending => Icons.insights_outlined,
    ReportInsightKind.refill => Icons.event_repeat_outlined,
    ReportInsightKind.price => Icons.price_change_outlined,
  };
}
```

Use `SingleChildScrollView(scrollDirection: Axis.horizontal)` for narrow screens.

- [ ] **Step 3: Implement `RefillForecastCard`**

Show 30/60/90 day amounts as three columns and the earliest three forecast items below:

```dart
Text('30일');
Text(formatPrice(forecast.next30DaysAmount));
Text('${entry.daysUntilRefill}일 후');
Text(entry.item.name);
```

- [ ] **Step 4: Implement `PriceMovementList`**

Show item name, current/previous store, current price, and delta. Use `AppColors.danger` for increases and `AppColors.success` for decreases.

- [ ] **Step 5: Run widget tests**

Run:

```bash
flutter test test/widgets/reports/report_insight_strip_test.dart test/widgets/reports/refill_forecast_card_test.dart test/widgets/reports/price_movement_list_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/widgets/reports/report_insight_strip.dart lib/widgets/reports/refill_forecast_card.dart lib/widgets/reports/price_movement_list.dart test/widgets/reports/report_insight_strip_test.dart test/widgets/reports/refill_forecast_card_test.dart test/widgets/reports/price_movement_list_test.dart
git commit -m "feat: add rich report insight widgets"
```

---

### Task 8: Enhanced Category Breakdown

**Files:**
- Create: `lib/widgets/reports/enhanced_category_breakdown_list.dart`
- Modify: `lib/services/report_service.dart`
- Modify: `test/services/report_service_test.dart`
- Modify: `lib/screens/reports_screen.dart`

- [ ] **Step 1: Add category comparison model**

Add service tests for `categoryComparisonForMonth(DateTime month)`:

```dart
expect(rows.first.category, '가전/필터');
expect(rows.first.amount, 30000);
expect(rows.first.previousAmount, 10000);
expect(rows.first.deltaAmount, 20000);
expect(rows.first.purchaseCount, 1);
```

- [ ] **Step 2: Implement `CategoryComparison`**

```dart
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
```

- [ ] **Step 3: Implement comparison methods**

Add monthly and yearly methods in `ReportService`. Monthly compares selected month to previous month. Yearly compares selected year to previous year.

- [ ] **Step 4: Implement widget**

Render each category row with:

```dart
Text(row.category);
Text(formatPrice(row.amount));
Text('구매 ${row.purchaseCount}건');
Text(row.deltaAmount == 0 ? '변동 없음' : '${formatPrice(row.deltaAmount.abs())} ${row.deltaAmount > 0 ? '증가' : '감소'}');
LinearProgressIndicator(value: row.ratio);
```

- [ ] **Step 5: Run tests**

Run:

```bash
flutter test test/services/report_service_test.dart test/screens/reports_screen_year_view_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/services/report_service.dart lib/widgets/reports/enhanced_category_breakdown_list.dart lib/screens/reports_screen.dart test/services/report_service_test.dart
git commit -m "feat: enrich category report breakdown"
```

---

### Task 9: Wire Rich Sections Into ReportsScreen

**Files:**
- Modify: `lib/screens/reports_screen.dart`
- Modify: `test/screens/reports_screen_year_view_test.dart`
- Modify: `test/screens/reports_screen_month_filter_test.dart`

- [ ] **Step 1: Add screen assertions**

Monthly mode should show:

```dart
expect(find.textContaining('리포트'), findsWidgets);
expect(find.text('다가오는 재구매'), findsOneWidget);
expect(find.text('가격 변동'), findsOneWidget);
```

Yearly mode should still show:

```dart
expect(find.text('연간 지출 현황'), findsOneWidget);
expect(find.text('연간 월별 지출'), findsOneWidget);
```

- [ ] **Step 2: Compute screen data**

In `ReportsScreen.build`, after existing `service` creation:

```dart
final activeMonth = latest?.month ?? DateTime(DateTime.now().year, DateTime.now().month, 1);
final summary = isYearly
    ? service.yearlySummary(_selectedYear)
    : service.monthlySummary(activeMonth);
final insights = service.smartInsights(month: activeMonth);
final forecast = service.refillForecast();
final priceMovements = service.priceMovements(limit: 4);
final categoryRows = isYearly
    ? service.categoryComparisonForYear(_selectedYear)
    : service.categoryComparisonForMonth(activeMonth);
```

- [ ] **Step 3: Replace old summary and hardcoded AI card**

Use:

```dart
ReportHeroCard(title: isYearly ? '$_selectedYear년 리포트' : '${activeMonth.month}월 리포트', summary: summary)
ReportInsightStrip(insights: insights)
```

Delete the hardcoded `AI 인사이트` text because it currently claims a static savings value unrelated to data.

- [ ] **Step 4: Insert buylog-specific sections**

Place `RefillForecastCard` after insights in monthly mode. Place `PriceMovementList` after the trend chart in both modes. Replace inline category list with `EnhancedCategoryBreakdownList`.

- [ ] **Step 5: Run screen tests**

Run:

```bash
flutter test test/screens/reports_screen_month_filter_test.dart test/screens/reports_screen_year_view_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/reports_screen.dart test/screens/reports_screen_month_filter_test.dart test/screens/reports_screen_year_view_test.dart
git commit -m "feat: wire rich report sections"
```

---

### Task 10: Visual and Quality Verification

**Files:**
- No required source edits unless verification finds layout/test failures.

- [ ] **Step 1: Format**

Run:

```bash
dart format lib test
```

Expected: files formatted without errors.

- [ ] **Step 2: Analyze**

Run:

```bash
flutter analyze
```

Expected: no new warnings or errors.

- [ ] **Step 3: Full tests**

Run:

```bash
flutter test
```

Expected: PASS.

- [ ] **Step 4: Manual visual pass**

Run:

```bash
flutter run -d chrome
```

Check:

- 리포트 첫 화면에서 총액, 인사이트, 교체 예산, 차트 일부가 과밀하지 않게 보인다.
- 작은 모바일 폭에서 KPI 칩과 인사이트 카드 텍스트가 넘치지 않는다.
- 월간/연간 전환 시 기존 테스트 기대 문구가 유지된다.
- 막대 차트 월 탭 상세 내역이 기존처럼 토글된다.

- [ ] **Step 5: Final commit**

```bash
git add lib test docs/superpowers/plans/2026-05-27-rich-reports-page.md
git commit -m "docs: plan rich reports page"
```

---

## Rollout Notes

- 신규 패키지 추가는 하지 않는다. `fl_chart`와 기존 Material 위젯으로 충분하다.
- `ReportService`가 커질 수 있으므로, 구현 중 300~350라인을 넘으면 `lib/services/report_models.dart` 또는 `lib/models/report_metrics.dart`로 값 객체만 분리한다.
- 화면의 한국어 문구는 짧게 유지한다. 예: `다가오는 재구매`, `가격 변동`, `전월 대비`, `구매 n건`.
- 현재 `ReportsScreen`은 `SampleData.items`를 직접 사용한다. 실제 Supabase/ItemStore 연결은 별도 계획으로 분리한다.

## Self-Review

- Spec coverage: 사용자의 "차별점 또는 강점 느낌" 요구는 소모품 재구매 예측, 가격 변동, 스마트 인사이트, 강화된 카테고리 분석으로 반영했다.
- Placeholder scan: 구현을 미루는 placeholder 없이 각 작업의 파일, 테스트, 코드 형태, 실행 명령을 명시했다.
- Type consistency: `ReportPeriodSummary`, `RefillForecast`, `PriceMovement`, `ReportInsight`, `CategoryComparison` 이름을 전 작업에서 일관되게 사용했다.
- Scope check: Supabase 실데이터 연결, 그룹 리포트, 공유 기능 실구현은 별도 PR 범위로 남겼다.
