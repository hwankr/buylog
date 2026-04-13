import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:buylog/services/report_service.dart';
import 'package:buylog/theme/app_theme.dart';
import 'package:buylog/widgets/reports/monthly_bar_chart.dart';

const _highlightColor = AppColors.primary;

List<MonthlySpending> _fixture() {
  return <MonthlySpending>[
    MonthlySpending(
      month: DateTime(2026, 1, 1),
      totalAmount: 10000,
      byCategory: const {'세탁': 10000},
      items: const [],
    ),
    MonthlySpending(
      month: DateTime(2026, 2, 1),
      totalAmount: 20000,
      byCategory: const {'주방': 20000},
      items: const [],
    ),
    MonthlySpending(
      month: DateTime(2026, 3, 1),
      totalAmount: 30000,
      byCategory: const {'필터': 30000},
      items: const [],
    ),
  ];
}

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

List<Color?> _readBarColors(WidgetTester tester) {
  final chart = tester.widget<BarChart>(find.byType(BarChart));
  return chart.data.barGroups.map((g) => g.barRods.first.color).toList();
}

void main() {
  // monthly_bar_chart.dart:88 의 `final highlighted = isSelected || isLatest;`
  // OR 동작을 spec-lock. PR2 는 monthly_bar_chart.dart 를 수정하지 않는다.
  group('MonthlyBarChart highlight (isSelected || isLatest spec-lock)', () {
    testWidgets('selectedMonth=null → 마지막 막대만 진한 색', (tester) async {
      await tester.pumpWidget(_wrap(MonthlyBarChart(data: _fixture())));

      final colors = _readBarColors(tester);
      expect(colors.length, 3);
      expect(colors[0], isNot(_highlightColor));
      expect(colors[1], isNot(_highlightColor));
      expect(colors[2], _highlightColor);
    });

    testWidgets('selectedMonth=2026-01-01 (non-latest) → 1월과 3월 둘 다 진한 색', (
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
      expect(colors[0], _highlightColor);
      expect(colors[1], isNot(_highlightColor));
      expect(colors[2], _highlightColor);
    });

    testWidgets('selectedMonth=2026-03-01 (latest) → 3월만 진한 색', (tester) async {
      await tester.pumpWidget(
        _wrap(
          MonthlyBarChart(
            data: _fixture(),
            selectedMonth: DateTime(2026, 3, 1),
          ),
        ),
      );

      final colors = _readBarColors(tester);
      expect(colors[0], isNot(_highlightColor));
      expect(colors[1], isNot(_highlightColor));
      expect(colors[2], _highlightColor);
    });
  });
}
