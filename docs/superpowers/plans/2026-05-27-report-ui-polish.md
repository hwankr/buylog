# Report UI Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 리포트 페이지의 막대 그래프 색/글자 조화와 리포트 섹션의 시각 일관성을 warm-neutral 디자인에 맞게 개선한다.

**Architecture:** 비즈니스 집계 로직은 `ReportService`에 그대로 두고, 리포트 전용 색상 판단을 `lib/widgets/reports/report_palette.dart`로 분리한다. `MonthlyBarChart`, 카테고리 차트, 인사이트 카드, 관련 리스트 위젯은 같은 팔레트를 소비해 차트와 아이콘의 색상 체계를 맞춘다. `ReportsScreen`은 섹션 순서와 배치만 조정한다.

**Tech Stack:** Flutter, Dart, Material 3, `fl_chart`, `flutter_test`

---

## Current UI Findings

- `lib/widgets/reports/monthly_bar_chart.dart`는 강조 막대에 `AppColors.primary`, 나머지 막대에 `AppColors.primary.withValues(alpha: 0.3)`을 사용한다. 현재 surface 위에서 30% primary 블렌드는 `#EAC9BF`이며 surface 대비가 약 `1.46:1`이라 막대가 배경에 묻힌다.
- 선택 월과 최신 월이 모두 `AppColors.primary`라서, 사용자가 오래된 월을 선택했을 때 "선택"과 "최신"이 같은 상태처럼 보인다.
- 막대 차트 하단 월 라벨은 `AppColors.textMuted`를 11px로 사용한다. surface 대비는 약 `3.48:1`이라 작은 글자에서 흐리다.
- `lib/widgets/reports/category_pie_chart.dart`는 `#0891B2`, `#7C3AED` 같은 cool 계열 색을 하드코딩한다. `docs/REDESIGN_NOTES.md`도 이 파일의 색이 warm 팔레트와 어긋난다고 기록하고 있다.
- `ReportInsightStrip`은 모든 인사이트를 `primaryLight2` 배경과 `primary` 텍스트로 보여준다. 인사이트 종류별 구분이 약하고, `primary` on `primaryLight2` 대비는 약 `3.31:1`이다.
- 리포트 화면은 카테고리 도넛 차트가 막대 차트보다 먼저 나온다. 지출 추이를 먼저 확인한 뒤 카테고리 구성으로 내려가는 흐름이 더 자연스럽다.

## File Structure

- Create `lib/widgets/reports/report_palette.dart`
  - 리포트 전용 막대, 카테고리, 인사이트 색상과 tint 계산을 담당한다.
- Create `test/widgets/reports/report_palette_test.dart`
  - 막대 상태별 색, 카테고리 색, 인사이트 색을 고정한다.
- Modify `lib/widgets/reports/monthly_bar_chart.dart`
  - 막대 상태별 색, 월 라벨 색, y축 보조 라벨, tooltip을 개선한다.
- Modify `test/widgets/reports/monthly_bar_chart_highlight_test.dart`
  - 기존 `isSelected || isLatest` 단색 spec-lock을 선택/최신 분리 spec-lock으로 갱신한다.
- Modify `lib/widgets/reports/category_pie_chart.dart`
  - cool 계열 하드코딩 팔레트를 제거하고 `ReportPalette`를 사용한다.
- Create `test/widgets/reports/category_pie_chart_test.dart`
  - 도넛 차트 section 색이 warm 리포트 팔레트를 사용하는지 검증한다.
- Modify `lib/widgets/reports/enhanced_category_breakdown_list.dart`
- Modify `lib/widgets/reports/refill_forecast_card.dart`
- Modify `lib/widgets/reports/price_movement_list.dart`
- Modify `lib/widgets/reports/month_filter_list_view.dart`
  - 카테고리 색상 의존을 `category_pie_chart.dart`에서 `report_palette.dart`로 옮긴다.
- Modify `lib/widgets/reports/report_insight_strip.dart`
  - 인사이트 종류별 색, 배경 tint, viewport 기반 카드 폭을 적용한다.
- Modify `test/widgets/reports/report_insight_strip_test.dart`
  - 작은 viewport에서도 카드가 화면 폭 안에 들어오는지 검증한다.
- Modify `lib/screens/reports_screen.dart`
  - 막대 그래프 섹션을 카테고리 구성 섹션보다 먼저 보여준다.
- Modify `test/screens/reports_screen_month_filter_test.dart`
  - 리포트 화면에서 추이 섹션이 카테고리 구성보다 위에 있는지 검증한다.

---

### Task 1: Report Palette

**Files:**
- Create: `lib/widgets/reports/report_palette.dart`
- Create: `test/widgets/reports/report_palette_test.dart`

- [ ] **Step 1: Write the failing palette tests**

Create `test/widgets/reports/report_palette_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:buylog/services/report_service.dart';
import 'package:buylog/theme/app_theme.dart';
import 'package:buylog/widgets/reports/report_palette.dart';

void main() {
  group('ReportPalette', () {
    test('returns explicit chart colors for selected, latest, idle, and empty bars', () {
      expect(
        ReportPalette.barColor(
          isSelected: true,
          isLatest: false,
          hasValue: true,
        ),
        AppColors.primaryDark,
      );
      expect(
        ReportPalette.barColor(
          isSelected: false,
          isLatest: true,
          hasValue: true,
        ),
        AppColors.primary,
      );
      expect(
        ReportPalette.barColor(
          isSelected: false,
          isLatest: false,
          hasValue: true,
        ),
        const Color(0xFFC57868),
      );
      expect(
        ReportPalette.barColor(
          isSelected: false,
          isLatest: false,
          hasValue: false,
        ),
        AppColors.surfaceAlt,
      );
    });

    test('maps report categories to warm palette colors', () {
      expect(ReportPalette.categoryColor('욕실/위생'), const Color(0xFF4D8B8C));
      expect(ReportPalette.categoryColor('가전/필터'), AppColors.success);
      expect(ReportPalette.categoryColor('세탁/청소'), AppColors.warning);
      expect(ReportPalette.categoryColor('주방/세제'), const Color(0xFF8B5E83));
      expect(ReportPalette.categoryColor('헤어/바디'), AppColors.danger);
      expect(ReportPalette.categoryColor('알 수 없음'), AppColors.textSecondary);
    });

    test('maps insight kinds to distinct semantic colors', () {
      expect(
        ReportPalette.insightColor(ReportInsightKind.refill),
        AppColors.success,
      );
      expect(
        ReportPalette.insightColor(ReportInsightKind.spending),
        AppColors.primaryDark,
      );
      expect(
        ReportPalette.insightColor(ReportInsightKind.price),
        AppColors.warning,
      );
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
flutter test test/widgets/reports/report_palette_test.dart
```

Expected: FAIL with `Error: Error when reading 'lib/widgets/reports/report_palette.dart'`.

- [ ] **Step 3: Implement the report palette**

Create `lib/widgets/reports/report_palette.dart`:

```dart
import 'package:flutter/material.dart';

import '../../services/report_service.dart';
import '../../theme/app_theme.dart';

class ReportPalette {
  static const chartIdle = Color(0xFFC57868);
  static const chartGrid = Color(0xFFE7DDCC);

  static const hygiene = Color(0xFF4D8B8C);
  static const kitchen = Color(0xFF8B5E83);

  static const Map<String, Color> categoryColors = <String, Color>{
    '위생': hygiene,
    '욕실/위생': hygiene,
    '필터': AppColors.success,
    '가전/필터': AppColors.success,
    '세탁': AppColors.warning,
    '세탁/청소': AppColors.warning,
    '주방': kitchen,
    '주방/세제': kitchen,
    '헤어/바디': AppColors.danger,
    '기타': AppColors.textSecondary,
  };

  static Color barColor({
    required bool isSelected,
    required bool isLatest,
    required bool hasValue,
  }) {
    if (!hasValue) return AppColors.surfaceAlt;
    if (isSelected) return AppColors.primaryDark;
    if (isLatest) return AppColors.primary;
    return chartIdle;
  }

  static Color categoryColor(String name) =>
      categoryColors[name] ?? AppColors.textSecondary;

  static Color categoryTint(String name, {double alpha = 0.12}) =>
      categoryColor(name).withValues(alpha: alpha);

  static Color insightColor(ReportInsightKind kind) {
    return switch (kind) {
      ReportInsightKind.refill => AppColors.success,
      ReportInsightKind.spending => AppColors.primaryDark,
      ReportInsightKind.price => AppColors.warning,
    };
  }

  static Color insightSurface(ReportInsightKind kind) {
    return Color.alphaBlend(
      insightColor(kind).withValues(alpha: 0.12),
      AppColors.surface,
    );
  }
}

Color colorForCategory(String name) => ReportPalette.categoryColor(name);
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
flutter test test/widgets/reports/report_palette_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/reports/report_palette.dart test/widgets/reports/report_palette_test.dart
git commit -m "feat: add report palette"
```

---

### Task 2: Category Color Migration

**Files:**
- Modify: `lib/widgets/reports/category_pie_chart.dart`
- Modify: `lib/widgets/reports/enhanced_category_breakdown_list.dart`
- Modify: `lib/widgets/reports/refill_forecast_card.dart`
- Modify: `lib/widgets/reports/price_movement_list.dart`
- Modify: `lib/widgets/reports/month_filter_list_view.dart`
- Create: `test/widgets/reports/category_pie_chart_test.dart`

- [ ] **Step 1: Write the failing category chart test**

Create `test/widgets/reports/category_pie_chart_test.dart`:

```dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:buylog/services/report_service.dart';
import 'package:buylog/theme/app_theme.dart';
import 'package:buylog/widgets/reports/category_pie_chart.dart';
import 'package:buylog/widgets/reports/report_palette.dart';

void main() {
  testWidgets('CategoryPieChart uses the warm report palette', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CategoryPieChart(
            data: [
              CategoryBreakdown(
                category: '욕실/위생',
                amount: 15000,
                ratio: 0.6,
              ),
              CategoryBreakdown(
                category: '주방/세제',
                amount: 10000,
                ratio: 0.4,
              ),
            ],
          ),
        ),
      ),
    );

    final chart = tester.widget<PieChart>(find.byType(PieChart));

    expect(chart.data.sections[0].color, ReportPalette.categoryColor('욕실/위생'));
    expect(chart.data.sections[1].color, ReportPalette.categoryColor('주방/세제'));
    expect(chart.data.sections[0].color, isNot(const Color(0xFF0891B2)));
    expect(chart.data.sections[1].color, isNot(const Color(0xFF7C3AED)));
  });

  testWidgets('CategoryPieChart fallback color is readable textSecondary', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CategoryPieChart(
            data: [
              CategoryBreakdown(
                category: '새 카테고리',
                amount: 1000,
                ratio: 1,
              ),
            ],
          ),
        ),
      ),
    );

    final chart = tester.widget<PieChart>(find.byType(PieChart));

    expect(chart.data.sections.single.color, AppColors.textSecondary);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
flutter test test/widgets/reports/category_pie_chart_test.dart
```

Expected: FAIL because `CategoryPieChart` still uses the local cool palette.

- [ ] **Step 3: Update `CategoryPieChart` to use `ReportPalette`**

In `lib/widgets/reports/category_pie_chart.dart`, remove `_categoryPalette` and the local `colorForCategory` implementation. Add this import:

```dart
import 'report_palette.dart';
```

Keep the public helper for compatibility:

```dart
Color colorForCategory(String name) => ReportPalette.categoryColor(name);
```

The `PieChartSectionData` and legend swatch code should keep calling `colorForCategory(c.category)`.

- [ ] **Step 4: Move list widgets to the palette import**

In each file below, replace:

```dart
import 'category_pie_chart.dart';
```

with:

```dart
import 'report_palette.dart';
```

Files:

```text
lib/widgets/reports/enhanced_category_breakdown_list.dart
lib/widgets/reports/refill_forecast_card.dart
lib/widgets/reports/price_movement_list.dart
lib/widgets/reports/month_filter_list_view.dart
```

No call-site rename is needed because `report_palette.dart` exports the top-level `colorForCategory(String name)` helper.

- [ ] **Step 5: Run category and dependent widget tests**

Run:

```bash
flutter test test/widgets/reports/category_pie_chart_test.dart test/widgets/reports/enhanced_category_breakdown_list_test.dart test/widgets/reports/refill_forecast_card_test.dart test/widgets/reports/price_movement_list_test.dart test/widgets/reports/month_filter_list_view_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/widgets/reports/category_pie_chart.dart lib/widgets/reports/enhanced_category_breakdown_list.dart lib/widgets/reports/refill_forecast_card.dart lib/widgets/reports/price_movement_list.dart lib/widgets/reports/month_filter_list_view.dart test/widgets/reports/category_pie_chart_test.dart
git commit -m "refactor: align report category colors"
```

---

### Task 3: Monthly Bar Chart Visual States

**Files:**
- Modify: `lib/widgets/reports/monthly_bar_chart.dart`
- Modify: `test/widgets/reports/monthly_bar_chart_highlight_test.dart`

- [ ] **Step 1: Update the chart state tests**

In `test/widgets/reports/monthly_bar_chart_highlight_test.dart`, replace the color constant and group description with:

```dart
import 'package:buylog/widgets/reports/report_palette.dart';

const _selectedColor = AppColors.primaryDark;
const _latestColor = AppColors.primary;
const _idleColor = ReportPalette.chartIdle;
const _emptyColor = AppColors.surfaceAlt;
```

Replace the test group body with:

```dart
group('MonthlyBarChart highlight states', () {
  testWidgets('selectedMonth=null → 마지막 막대는 latest, 나머지는 idle', (tester) async {
    await tester.pumpWidget(_wrap(MonthlyBarChart(data: _fixture())));

    final colors = _readBarColors(tester);
    expect(colors.length, 3);
    expect(colors[0], _idleColor);
    expect(colors[1], _idleColor);
    expect(colors[2], _latestColor);
  });

  testWidgets('selectedMonth=2026-01-01 → 선택 막대와 최신 막대가 다른 색', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        MonthlyBarChart(
          data: _fixture(),
          selectedMonth: DateTime(2026, 1, 1),
        ),
      ),
    );

    final colors = _readBarColors(tester);
    expect(colors[0], _selectedColor);
    expect(colors[1], _idleColor);
    expect(colors[2], _latestColor);
  });

  testWidgets('selectedMonth=latest → 선택 색이 latest 색보다 우선한다', (tester) async {
    await tester.pumpWidget(
      _wrap(
        MonthlyBarChart(
          data: _fixture(),
          selectedMonth: DateTime(2026, 3, 1),
        ),
      ),
    );

    final colors = _readBarColors(tester);
    expect(colors[0], _idleColor);
    expect(colors[1], _idleColor);
    expect(colors[2], _selectedColor);
  });

  testWidgets('highlightLatest=false → 선택 월만 selected 색', (tester) async {
    await tester.pumpWidget(
      _wrap(
        MonthlyBarChart(
          data: _fixture(),
          selectedMonth: DateTime(2026, 1, 1),
          highlightLatest: false,
        ),
      ),
    );

    final colors = _readBarColors(tester);
    expect(colors[0], _selectedColor);
    expect(colors[1], _idleColor);
    expect(colors[2], _idleColor);
  });

  testWidgets('0원 막대는 surfaceAlt 색으로 표시한다', (tester) async {
    final fixture = <MonthlySpending>[
      MonthlySpending(
        month: DateTime(2026, 1, 1),
        totalAmount: 0,
        byCategory: const {},
        items: const [],
      ),
      MonthlySpending(
        month: DateTime(2026, 2, 1),
        totalAmount: 20000,
        byCategory: const {'주방': 20000},
        items: const [],
      ),
    ];

    await tester.pumpWidget(_wrap(MonthlyBarChart(data: fixture)));

    final colors = _readBarColors(tester);
    expect(colors[0], _emptyColor);
    expect(colors[1], _latestColor);
  });
});
```

- [ ] **Step 2: Add chart readability assertions**

Add this test below the highlight group:

```dart
testWidgets('MonthlyBarChart shows y-axis labels and tooltip formatting', (tester) async {
  await tester.pumpWidget(_wrap(MonthlyBarChart(data: _fixture())));

  final chart = tester.widget<BarChart>(find.byType(BarChart));

  expect(chart.data.titlesData.leftTitles.sideTitles.showTitles, isTrue);
  expect(chart.data.titlesData.leftTitles.sideTitles.reservedSize, 40);
  expect(chart.data.gridData.getDrawingHorizontalLine(50000).color, ReportPalette.chartGrid);

  final tooltip = chart.data.barTouchData.touchTooltipData.getTooltipItem(
    chart.data.barGroups[1],
    1,
    chart.data.barGroups[1].barRods.first,
    0,
  );

  expect(tooltip?.text, contains('2월'));
  expect(tooltip?.text, contains('20,000원'));
});
```

- [ ] **Step 3: Run tests to verify they fail**

Run:

```bash
flutter test test/widgets/reports/monthly_bar_chart_highlight_test.dart
```

Expected: FAIL because `MonthlyBarChart` still uses `primary.withValues(alpha: 0.3)`, hides left titles, and does not format custom tooltip text.

- [ ] **Step 4: Update `MonthlyBarChart` imports and helpers**

Add imports to `lib/widgets/reports/monthly_bar_chart.dart`:

```dart
import '../../utils/price_format.dart';
import 'report_palette.dart';
```

Add helper methods inside `MonthlyBarChart`:

```dart
double _barWidthFor(int count) => count > 8 ? 18 : 24;

String _axisPriceLabel(double value) {
  if (value <= 0) return '';
  if (value >= 10000) return '${(value / 10000).round()}만';
  return value.round().toString();
}
```

- [ ] **Step 5: Update chart data options**

Inside `BarChartData`, replace the grid and title configuration with:

```dart
gridData: FlGridData(
  show: true,
  drawVerticalLine: false,
  horizontalInterval: computedMaxY / 4,
  getDrawingHorizontalLine: (value) =>
      const FlLine(color: ReportPalette.chartGrid, strokeWidth: 0.5),
),
titlesData: FlTitlesData(
  topTitles: const AxisTitles(
    sideTitles: SideTitles(showTitles: false),
  ),
  rightTitles: const AxisTitles(
    sideTitles: SideTitles(showTitles: false),
  ),
  leftTitles: AxisTitles(
    sideTitles: SideTitles(
      showTitles: true,
      reservedSize: 40,
      interval: computedMaxY / 2,
      getTitlesWidget: (value, meta) {
        final label = _axisPriceLabel(value);
        if (label.isEmpty) return const SizedBox.shrink();
        return Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        );
      },
    ),
  ),
  bottomTitles: AxisTitles(
    sideTitles: SideTitles(
      showTitles: true,
      reservedSize: 30,
      getTitlesWidget: (value, meta) {
        final index = value.toInt();
        if (index >= 0 && index < data.length) {
          final isLatest = index == data.length - 1;
          final isSelected =
              selectedMonth != null && data[index].month == selectedMonth;
          final highlighted = isSelected || (highlightLatest && isLatest);
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '${data[index].month.month}월',
              style: TextStyle(
                fontSize: 11,
                fontWeight: highlighted ? FontWeight.w800 : FontWeight.w600,
                color: highlighted
                    ? AppColors.primaryDark
                    : AppColors.textSecondary,
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    ),
  ),
),
```

- [ ] **Step 6: Add custom tooltip formatting**

Inside `barTouchData`, keep the existing `touchCallback` and add `touchTooltipData`:

```dart
touchTooltipData: BarTouchTooltipData(
  getTooltipColor: (_) => AppColors.text,
  tooltipBorderRadius: BorderRadius.circular(8),
  tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
  fitInsideHorizontally: true,
  getTooltipItem: (group, groupIndex, rod, rodIndex) {
    final month = data[group.x.toInt()].month;
    final amount = data[group.x.toInt()].totalAmount;
    return BarTooltipItem(
      '${month.month}월\n${formatPrice(amount)}',
      const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        height: 1.25,
      ),
    );
  },
),
```

- [ ] **Step 7: Replace bar color and width logic**

Inside `barGroups`, replace the `BarChartRodData` color and width with:

```dart
width: _barWidthFor(data.length),
color: ReportPalette.barColor(
  isSelected: isSelected,
  isLatest: highlightLatest && isLatest,
  hasValue: entry.value.totalAmount > 0,
),
```

Keep the existing rounded top corners.

- [ ] **Step 8: Run chart tests**

Run:

```bash
flutter test test/widgets/reports/monthly_bar_chart_highlight_test.dart test/widgets/reports/monthly_bar_chart_tap_test.dart
```

Expected: PASS. The tap tests must continue to pass because the `FlTapUpEvent` gate is preserved.

- [ ] **Step 9: Commit**

```bash
git add lib/widgets/reports/monthly_bar_chart.dart test/widgets/reports/monthly_bar_chart_highlight_test.dart
git commit -m "feat: refine report bar chart colors"
```

---

### Task 4: Insight Strip Color and Width

**Files:**
- Modify: `lib/widgets/reports/report_insight_strip.dart`
- Modify: `test/widgets/reports/report_insight_strip_test.dart`

- [ ] **Step 1: Add responsive width test**

Add this test to `test/widgets/reports/report_insight_strip_test.dart`:

```dart
testWidgets('ReportInsightStrip constrains cards to the available width', (tester) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 220,
          child: ReportInsightStrip(
            insights: [
              ReportInsight(
                kind: ReportInsightKind.refill,
                title: '다가오는 재구매',
                body: '30일 안에 2개 품목이 필요해요.',
                priority: 30,
              ),
            ],
          ),
        ),
      ),
    ),
  );

  final fixedWidths = tester
      .widgetList<SizedBox>(find.byType(SizedBox))
      .map((box) => box.width)
      .whereType<double>()
      .toList();

  expect(fixedWidths, contains(220));
  expect(fixedWidths.where((width) => width > 220), isEmpty);
});
```

- [ ] **Step 2: Run test to verify it fails or exposes the current fixed width**

Run:

```bash
flutter test test/widgets/reports/report_insight_strip_test.dart
```

Expected: FAIL because the strip currently creates an inner `SizedBox(width: 250)` even when the available width is 220.

- [ ] **Step 3: Update `ReportInsightStrip` to use `ReportPalette` and `LayoutBuilder`**

In `lib/widgets/reports/report_insight_strip.dart`, add:

```dart
import 'report_palette.dart';
```

Replace the `SingleChildScrollView` return with:

```dart
return LayoutBuilder(
  builder: (context, constraints) {
    final availableWidth = constraints.maxWidth.isFinite
        ? constraints.maxWidth
        : MediaQuery.sizeOf(context).width - 40;
    final cardWidth = availableWidth < 250 ? availableWidth : 250.0;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (var i = 0; i < insights.length; i++) ...[
            SizedBox(
              width: cardWidth,
              child: _InsightCard(insight: insights[i]),
            ),
            if (i != insights.length - 1) const SizedBox(width: 10),
          ],
        ],
      ),
    );
  },
);
```

- [ ] **Step 4: Update `_InsightCard` colors**

Inside `_InsightCard.build`, add:

```dart
final accent = ReportPalette.insightColor(insight.kind);
final surface = ReportPalette.insightSurface(insight.kind);
```

Replace the decoration and icon/title colors with:

```dart
decoration: BoxDecoration(
  color: surface,
  borderRadius: BorderRadius.circular(14),
  border: Border.all(
    color: accent.withValues(alpha: 0.22),
    width: 0.5,
  ),
),
```

```dart
color: accent.withValues(alpha: 0.14),
```

```dart
color: accent,
```

For the title text style, use readable ink instead of the accent color:

```dart
style: const TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w800,
  color: AppColors.text,
),
```

Keep the body text as `AppColors.text`.

- [ ] **Step 5: Run insight tests**

Run:

```bash
flutter test test/widgets/reports/report_insight_strip_test.dart test/widgets/reports/report_palette_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/widgets/reports/report_insight_strip.dart test/widgets/reports/report_insight_strip_test.dart
git commit -m "feat: refine report insight cards"
```

---

### Task 5: Report Section Order

**Files:**
- Modify: `lib/screens/reports_screen.dart`
- Modify: `test/screens/reports_screen_month_filter_test.dart`

- [ ] **Step 1: Add a screen order test**

Add this test to `test/screens/reports_screen_month_filter_test.dart`:

```dart
testWidgets('지출 추이 섹션이 카테고리 구성보다 먼저 보인다', (tester) async {
  await _pumpReportsScreen(tester);

  final trendTop = tester.getTopLeft(find.text('월별 지출 추이')).dy;
  final categoryTop = tester
      .getTopLeft(find.textContaining('월 카테고리 구성'))
      .dy;

  expect(trendTop, lessThan(categoryTop));
});
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
flutter test test/screens/reports_screen_month_filter_test.dart
```

Expected: FAIL because `ReportsScreen` currently places the category pie section before the monthly bar chart section.

- [ ] **Step 3: Move the chart section above the category pie section**

In `lib/screens/reports_screen.dart`, move the `SliverToBoxAdapter` whose title is `chartTitle` so it appears before the `SliverToBoxAdapter` whose title is `pieTitle`.

The new order after `RefillForecastCard` should be:

```dart
SliverToBoxAdapter(
  child: Padding(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
    child: _ReportSectionCard(
      title: chartTitle,
      child: MonthlyBarChart(
        data: chartData,
        selectedMonth: effectiveSelectedMonth,
        onMonthTap: _onMonthTap,
        highlightLatest: !isYearly,
      ),
    ),
  ),
),
SliverToBoxAdapter(
  child: Padding(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
    child: _ReportSectionCard(
      title: pieTitle,
      child: CategoryPieChart(data: breakdown),
    ),
  ),
),
```

Do not change the `MonthFilterListView` state logic in this task.

- [ ] **Step 4: Run screen tests**

Run:

```bash
flutter test test/screens/reports_screen_month_filter_test.dart test/screens/reports_screen_year_view_test.dart
```

Expected: PASS. Existing month selection, stale month, and yearly view tests must still pass.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/reports_screen.dart test/screens/reports_screen_month_filter_test.dart
git commit -m "feat: reorder report chart sections"
```

---

### Task 6: Final Verification

**Files:**
- No source edits are planned in this task.

- [ ] **Step 1: Format**

Run:

```bash
dart format lib test
```

Expected: formatting completes without errors.

- [ ] **Step 2: Analyze**

Run:

```bash
flutter analyze
```

Expected: no new errors or warnings.

- [ ] **Step 3: Run targeted report tests**

Run:

```bash
flutter test test/widgets/reports/report_palette_test.dart test/widgets/reports/category_pie_chart_test.dart test/widgets/reports/monthly_bar_chart_highlight_test.dart test/widgets/reports/monthly_bar_chart_tap_test.dart test/widgets/reports/report_insight_strip_test.dart test/screens/reports_screen_month_filter_test.dart test/screens/reports_screen_year_view_test.dart
```

Expected: PASS.

- [ ] **Step 4: Run the full test suite**

Run:

```bash
flutter test
```

Expected: PASS.

- [ ] **Step 5: Manual visual pass**

Run:

```bash
flutter run -d chrome
```

Check these points on the report tab:

- 막대 차트에서 선택 월은 진한 terracotta, 최신 월은 기존 primary, 일반 월은 muted clay, 0원 월은 surfaceAlt로 구분된다.
- 막대 하단 월 라벨이 배경에 묻히지 않고, 선택/최신 월 라벨은 더 굵게 보인다.
- y축 보조 라벨과 grid line이 차트를 설명하지만 시선을 빼앗지 않는다.
- 카테고리 도넛, 카테고리 상세, 가격 변동, 재구매 아이콘 색이 같은 warm 계열로 이어진다.
- 인사이트 카드가 refill/spending/price 종류별 accent를 갖지만 제목과 본문은 readable ink 색으로 읽힌다.
- 월간/연간 전환 후에도 추이 섹션이 카테고리 구성보다 먼저 보인다.
- 360px 폭에서도 인사이트 카드 텍스트가 부모 영역 밖으로 튀어나가지 않는다.

- [ ] **Step 6: Commit plan document**

```bash
git add docs/superpowers/plans/2026-05-27-report-ui-polish.md
git commit -m "docs: plan report ui polish"
```

---

## Rollout Notes

- 새 패키지를 추가하지 않는다.
- `ReportService`와 집계 모델은 수정하지 않는다.
- `MonthlyBarChart`의 tap dedup 로직은 유지한다. `test/widgets/reports/monthly_bar_chart_tap_test.dart`가 회귀 방지 역할을 한다.
- 기존 `colorForCategory(String name)` helper는 `report_palette.dart`로 옮기되 같은 이름을 유지한다.
- 시각 대비 기준은 작은 텍스트에 `AppColors.textSecondary` 이상을 쓰는 방향으로 맞춘다. accent 색은 아이콘, 막대, swatch, border에 주로 사용한다.

## Self-Review

- Spec coverage: 사용자가 지적한 막대 색/글자 조화는 Task 1과 Task 3에서 해결한다. 추가 UI 보완 지점인 카테고리 cool palette, 인사이트 카드 단색감, 섹션 순서는 Task 2, Task 4, Task 5에서 다룬다.
- Placeholder scan: 모든 파일 경로, 테스트 명령, 코드 변경 예시가 구체적이다. 미정 상태의 항목은 없다.
- Type consistency: `ReportPalette`, `barColor`, `categoryColor`, `categoryTint`, `insightColor`, `insightSurface` 이름은 전 태스크에서 동일하게 사용한다.
- Scope check: 비즈니스 로직, Supabase 연동, 데이터 모델 변경은 제외했다. 이번 계획은 리포트 화면의 시각 품질 개선에만 집중한다.
