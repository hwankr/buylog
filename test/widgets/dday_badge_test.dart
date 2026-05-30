import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:buylog/widgets/countdown_ring.dart';
import 'package:buylog/widgets/dday_badge.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('D-day overdue display', () {
    testWidgets('DdayBadge shows overdue days as D+N instead of D--N', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const DdayBadge(daysRemaining: -6)));

      expect(find.text('D+6'), findsOneWidget);
      expect(find.text('D--6'), findsNothing);
    });

    testWidgets('DdayBadge keeps today as D-Day', (tester) async {
      await tester.pumpWidget(_wrap(const DdayBadge(daysRemaining: 0)));

      expect(find.text('D-Day'), findsOneWidget);
      expect(find.text('D-0'), findsNothing);
    });

    testWidgets('CountdownRing explains overdue state instead of 교체까지', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const CountdownRing(daysRemaining: -3, totalDays: 30)),
      );

      expect(find.text('D+3'), findsOneWidget);
      expect(find.text('교체 지남'), findsOneWidget);
      expect(find.text('교체까지'), findsNothing);
    });
  });
}
