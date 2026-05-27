import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:buylog/models/item.dart';
import 'package:buylog/services/report_service.dart';
import 'package:buylog/widgets/reports/price_movement_list.dart';

void main() {
  testWidgets('PriceMovementList renders changed item and delta', (
    tester,
  ) async {
    final item = ConsumableItem(
      id: 'dish',
      name: '주방 세제',
      brand: '자연퐁',
      category: '주방/세제',
      icon: Icons.kitchen_outlined,
      daysRemaining: 10,
      cycleDays: 30,
      progress: 0.6,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PriceMovementList(
            movements: [
              PriceMovement(
                item: item,
                currentPrice: 6000,
                previousPrice: 4500,
                currentStore: '쿠팡',
                previousStore: '이마트',
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('가격 변동'), findsOneWidget);
    expect(find.text('주방 세제'), findsOneWidget);
    expect(find.text('6,000원'), findsOneWidget);
    expect(find.text('1,500원 상승'), findsOneWidget);
  });
}
