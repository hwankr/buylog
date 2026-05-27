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

  testWidgets('CategoryPieChart fallback color is readable textSecondary', (
    tester,
  ) async {
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
