import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:buylog/services/report_service.dart';
import 'package:buylog/widgets/reports/report_hero_card.dart';

void main() {
  testWidgets(
    'ReportHeroCard renders amount, delta, purchase count, and top category',
    (tester) async {
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
      expect(find.textContaining('가전/필터'), findsOneWidget);
    },
  );
}
