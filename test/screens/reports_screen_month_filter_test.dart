import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:buylog/screens/reports_screen.dart';
import 'package:buylog/widgets/reports/monthly_bar_chart.dart';

Widget _wrap() {
  return const MaterialApp(home: Scaffold(body: ReportsScreen()));
}

Future<void> _pumpReportsScreen(WidgetTester tester) async {
  // ReportsScreen 은 sliver 스택이 길어 기본 800x600 viewport 밖으로 밀리는
  // sliver 가 생긴다. SliverToBoxAdapter 의 lazy build 를 피하기 위해
  // viewport 를 충분히 키운다.
  await tester.binding.setSurfaceSize(const Size(800, 2000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(_wrap());
}

DateTime _firstNonZeroMonth(WidgetTester tester) {
  final chart = tester.widget<MonthlyBarChart>(find.byType(MonthlyBarChart));
  final nonZero = chart.data.where((m) => m.totalAmount > 0).toList();
  expect(
    nonZero,
    isNotEmpty,
    reason:
        'SampleData 의 6개월 윈도우에 non-zero 월이 없습니다. SampleData 갱신 또는 ReportService(now:) 주입이 필요합니다 (2026-09 cliff).',
  );
  return nonZero.last.month;
}

DateTime? _otherNonZeroMonth(WidgetTester tester, DateTime exclude) {
  final chart = tester.widget<MonthlyBarChart>(find.byType(MonthlyBarChart));
  final nonZero = chart.data
      .where((m) => m.totalAmount > 0 && m.month != exclude)
      .toList();
  return nonZero.isEmpty ? null : nonZero.last.month;
}

Future<void> _tap(WidgetTester tester, DateTime month) async {
  final chart = tester.widget<MonthlyBarChart>(find.byType(MonthlyBarChart));
  chart.onMonthTap?.call(month);
  await tester.pump();
}

void main() {
  group('ReportsScreen month filter toggle', () {
    testWidgets('초기 상태: 상세 헤더 없음', (tester) async {
      await _pumpReportsScreen(tester);
      expect(find.textContaining('상세 내역'), findsNothing);
    });

    testWidgets('첫 탭 → 해당 월 헤더 표시', (tester) async {
      await _pumpReportsScreen(tester);
      final target = _firstNonZeroMonth(tester);

      await _tap(tester, target);

      expect(find.text('${target.month}월 상세 내역'), findsOneWidget);
    });

    testWidgets('재탭 → 헤더 사라짐 (토글 해제)', (tester) async {
      await _pumpReportsScreen(tester);
      final target = _firstNonZeroMonth(tester);

      await _tap(tester, target);
      expect(find.text('${target.month}월 상세 내역'), findsOneWidget);

      await _tap(tester, target);
      expect(find.textContaining('상세 내역'), findsNothing);
    });

    testWidgets('다른 월 탭 → 새 헤더로 전환', (tester) async {
      await _pumpReportsScreen(tester);
      final first = _firstNonZeroMonth(tester);
      final other = _otherNonZeroMonth(tester, first);
      if (other == null) {
        markTestSkipped('SampleData 에 non-zero 월이 1개뿐이라 전환 케이스 검증 불가');
        return;
      }

      await _tap(tester, first);
      expect(find.text('${first.month}월 상세 내역'), findsOneWidget);

      await _tap(tester, other);
      expect(find.text('${first.month}월 상세 내역'), findsNothing);
      expect(find.text('${other.month}월 상세 내역'), findsOneWidget);
    });

    // Codex review v3.2 HIGH finding 회귀 방지.
    // IndexedStack 하에서 _selectedMonth 는 앱 수명만큼 유지되므로, 월 경계
    // 교차 또는 데이터 동기화로 현재 aggregateRecentMonths window 에 없는
    // 월이 선택 상태로 남으면 "헤더만 떠 있고 바 차트엔 해당 월 없음" 모순
    // 발생. build 에서 _selectedMonth 를 months 와 교차 검증하여 stale 선택을
    // 무효화해야 한다.
    testWidgets('window 밖 월이 선택 상태여도 stale 헤더가 뜨지 않는다', (tester) async {
      await _pumpReportsScreen(tester);

      // 현재 aggregateRecentMonths window 에는 절대 포함되지 않는 과거 월.
      final outOfWindow = DateTime(2020, 1, 1);
      await _tap(tester, outOfWindow);

      expect(
        find.text('${outOfWindow.month}월 상세 내역'),
        findsNothing,
        reason: 'window 밖 월은 effectiveSelectedMonth 에서 null 로 중화되어 헤더 미표시',
      );
      expect(find.textContaining('상세 내역'), findsNothing);
    });
  });
}
