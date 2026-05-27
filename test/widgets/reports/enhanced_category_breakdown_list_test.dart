import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:buylog/services/report_service.dart';
import 'package:buylog/widgets/reports/enhanced_category_breakdown_list.dart';

void main() {
  testWidgets('EnhancedCategoryBreakdownList renders category metrics', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EnhancedCategoryBreakdownList(
            title: '카테고리별 상세',
            rows: [
              CategoryComparison(
                category: '가전/필터',
                amount: 30000,
                previousAmount: 10000,
                purchaseCount: 1,
                ratio: 1,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('카테고리별 상세'), findsOneWidget);
    expect(find.text('가전/필터'), findsOneWidget);
    expect(find.text('30,000원'), findsOneWidget);
    expect(find.text('구매 1건'), findsOneWidget);
    expect(find.text('20,000원 증가'), findsOneWidget);
  });
}
