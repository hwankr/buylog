import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:buylog/screens/reports_screen.dart';

Widget _wrap() {
  return const MaterialApp(home: Scaffold(body: ReportsScreen()));
}

Future<void> _pumpReportsScreen(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(800, 2200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(_wrap());
}

void main() {
  group('ReportsScreen year view', () {
    testWidgets('shows month/year mode controls', (tester) async {
      await _pumpReportsScreen(tester);

      expect(find.text('월간'), findsOneWidget);
      expect(find.text('연간'), findsOneWidget);
    });

    testWidgets('tapping year mode shows annual summary and yearly trend', (
      tester,
    ) async {
      await _pumpReportsScreen(tester);

      await tester.tap(find.text('연간'));
      await tester.pump();

      final currentYear = DateTime.now().year;
      expect(find.text('연간 지출 현황'), findsOneWidget);
      expect(find.text('$currentYear년'), findsWidgets);
      expect(find.text('연간 월별 지출'), findsOneWidget);
      expect(find.text('월별 지출 추이'), findsNothing);
    });
  });
}
