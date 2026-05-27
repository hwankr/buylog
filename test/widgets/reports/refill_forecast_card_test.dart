import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:buylog/models/item.dart';
import 'package:buylog/services/report_service.dart';
import 'package:buylog/widgets/reports/refill_forecast_card.dart';

void main() {
  testWidgets('RefillForecastCard renders windows and upcoming items', (
    tester,
  ) async {
    final item = ConsumableItem(
      id: 'paper',
      name: '화장지',
      brand: '코디',
      category: '욕실/위생',
      icon: Icons.bathroom_outlined,
      daysRemaining: 12,
      cycleDays: 30,
      progress: 0.6,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RefillForecastCard(
            forecast: RefillForecast(
              next30DaysAmount: 15000,
              next60DaysAmount: 50000,
              next90DaysAmount: 50000,
              items: [
                RefillForecastItem(
                  item: item,
                  expectedPrice: 15000,
                  daysUntilRefill: 12,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('다가오는 재구매'), findsOneWidget);
    expect(find.text('30일'), findsOneWidget);
    expect(find.text('60일'), findsOneWidget);
    expect(find.text('90일'), findsOneWidget);
    expect(find.text('화장지'), findsOneWidget);
    expect(find.text('12일 후'), findsOneWidget);
  });
}
