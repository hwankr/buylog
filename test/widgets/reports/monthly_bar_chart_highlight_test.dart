import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:buylog/services/report_service.dart';
import 'package:buylog/theme/app_theme.dart';
import 'package:buylog/widgets/reports/monthly_bar_chart.dart';
import 'package:buylog/widgets/reports/report_palette.dart';

const _selectedColor = AppColors.primaryDark;
const _latestColor = AppColors.primary;
const _idleColor = ReportPalette.chartIdle;
const _emptyColor = AppColors.surfaceAlt;

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
  group('MonthlyBarChart highlight states', () {
    testWidgets('selectedMonth=null → 마지막 막대는 latest, 나머지는 idle', (
      tester,
    ) async {
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

  testWidgets('MonthlyBarChart shows y-axis labels and tooltip formatting', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(MonthlyBarChart(data: _fixture())));

    final chart = tester.widget<BarChart>(find.byType(BarChart));

    expect(chart.data.titlesData.leftTitles.sideTitles.showTitles, isTrue);
    expect(chart.data.titlesData.leftTitles.sideTitles.reservedSize, 40);
    expect(
      chart.data.gridData.getDrawingHorizontalLine(50000).color,
      ReportPalette.chartGrid,
    );

    final tooltip = chart.data.barTouchData.touchTooltipData.getTooltipItem(
      chart.data.barGroups[1],
      1,
      chart.data.barGroups[1].barRods.first,
      0,
    );

    expect(tooltip?.text, contains('2월'));
    expect(tooltip?.text, contains('20,000원'));
  });
}
