import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:buylog/services/report_service.dart';
import 'package:buylog/widgets/reports/report_insight_strip.dart';

void main() {
  testWidgets('ReportInsightStrip renders insight cards', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ReportInsightStrip(
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
    );

    expect(find.text('다가오는 재구매'), findsOneWidget);
    expect(find.textContaining('30일'), findsOneWidget);
  });

  testWidgets('ReportInsightStrip constrains cards to the available width', (
    tester,
  ) async {
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
}
