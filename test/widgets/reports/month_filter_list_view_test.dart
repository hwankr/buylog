import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:buylog/models/item.dart';
import 'package:buylog/services/report_service.dart';
import 'package:buylog/widgets/reports/month_filter_list_view.dart';

ReportService _buildService() {
  return ReportService.fromItems(<ConsumableItem>[
    ConsumableItem(
      id: 'a',
      name: '세탁세제',
      brand: '피죤',
      category: '세탁',
      icon: Icons.local_laundry_service_outlined,
      daysRemaining: 0,
      cycleDays: 30,
      progress: 0.5,
      createdAt: DateTime(2026, 3, 1),
      purchaseHistory: [
        PurchaseRecord(date: DateTime(2026, 3, 1), price: 12500, store: '이마트'),
      ],
    ),
    ConsumableItem(
      id: 'b',
      name: '주방세제',
      brand: '퐁퐁',
      category: '주방',
      icon: Icons.kitchen_outlined,
      daysRemaining: 0,
      cycleDays: 30,
      progress: 0.5,
      createdAt: DateTime(2026, 2, 18),
      purchaseHistory: [
        PurchaseRecord(date: DateTime(2026, 3, 20), price: 4500, store: '이마트'),
        PurchaseRecord(date: DateTime(2026, 2, 18), price: 4200, store: '쿠팡'),
      ],
    ),
  ]);
}

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  group('MonthFilterListView', () {
    testWidgets('selectedMonth==null → SizedBox.shrink (헤더 텍스트 없음)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          MonthFilterListView(selectedMonth: null, service: _buildService()),
        ),
      );

      expect(find.textContaining('상세 내역'), findsNothing);
      expect(find.textContaining('해당 월에 기록된'), findsNothing);
    });

    testWidgets('selectedMonth=2026-03-01 → 헤더 + 두 아이템 name 렌더', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          MonthFilterListView(
            selectedMonth: DateTime(2026, 3, 1),
            service: _buildService(),
          ),
        ),
      );

      expect(find.text('3월 상세 내역'), findsOneWidget);
      expect(find.text('세탁세제'), findsOneWidget);
      expect(find.text('주방세제'), findsOneWidget);
    });

    testWidgets('selectedMonth=2026-01-01 (데이터 없음) → empty-state 텍스트', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          MonthFilterListView(
            selectedMonth: DateTime(2026, 1, 1),
            service: _buildService(),
          ),
        ),
      );

      expect(find.text('1월 상세 내역'), findsOneWidget);
      expect(find.text('해당 월에 기록된 구매가 없어요'), findsOneWidget);
    });

    testWidgets('가격 12500 → "12,500원" 으로 천단위 콤마 포맷', (tester) async {
      await tester.pumpWidget(
        _wrap(
          MonthFilterListView(
            selectedMonth: DateTime(2026, 3, 1),
            service: _buildService(),
          ),
        ),
      );

      expect(find.text('12,500원'), findsOneWidget);
      expect(find.text('4,500원'), findsOneWidget);
    });
  });
}
