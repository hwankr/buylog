import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:buylog/services/report_service.dart';
import 'package:buylog/widgets/reports/monthly_bar_chart.dart';

List<MonthlySpending> _fixture() {
  return <MonthlySpending>[
    MonthlySpending(
      month: DateTime(2026, 1, 1),
      totalAmount: 10000,
      byCategory: const {'세탁': 10000},
      items: const [],
    ),
    MonthlySpending(
      month: DateTime(2026, 2, 1),
      totalAmount: 20000,
      byCategory: const {'주방': 20000},
      items: const [],
    ),
    MonthlySpending(
      month: DateTime(2026, 3, 1),
      totalAmount: 30000,
      byCategory: const {'필터': 30000},
      items: const [],
    ),
  ];
}

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

BarTouchResponse _stubResponseFor(BarChart chart, int barIndex) {
  final group = chart.data.barGroups[barIndex];
  return BarTouchResponse(
    touchLocation: Offset.zero,
    touchChartCoordinate: Offset.zero,
    spot: BarTouchedSpot(
      group,
      barIndex,
      group.barRods.first,
      0,
      null,
      -1,
      FlSpot(barIndex.toDouble(), 0),
      Offset.zero,
    ),
  );
}

void main() {
  // Codex adversarial review Finding 1 (v2) 회귀 방지 + Finding 1 (v3.1) 회귀
  // 방지. Option A (FlTapUpEvent 게이팅) 는:
  //   - desktop/web 에서도 TapUp 은 1회 emit → 단일 발화 보장.
  //   - CustomScrollView 안에서 스크롤 시작 시 TapCancel 이 와서 TapUp 대신
  //     게이트에서 무시 → 토글 발사 안 됨.
  //   - fl_chart CHANGELOG.md:341 공식 권장 패턴.
  //
  // 주의: debugDefaultTargetPlatformOverride 는 test body 종료 시점에 framework
  // 가 invariant 검증을 수행하므로 addTearDown 으로는 늦다. try/finally 로 즉시
  // 리셋해야 한다.
  group('MonthlyBarChart tap dedup (Option A — TapUp gating spec-lock)', () {
    testWidgets(
      'desktop/web 환경: TapDown + TapUp 호출 시 TapUp 에서만 onMonthTap 1회',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        try {
          var tapCount = 0;
          DateTime? lastMonth;
          final fixture = _fixture();

          await tester.pumpWidget(
            _wrap(
              MonthlyBarChart(
                data: fixture,
                onMonthTap: (m) {
                  tapCount++;
                  lastMonth = m;
                },
              ),
            ),
          );

          final chart = tester.widget<BarChart>(find.byType(BarChart));
          final callback = chart.data.barTouchData.touchCallback!;
          final stubResponse = _stubResponseFor(chart, 1);

          callback(
            FlTapDownEvent(TapDownDetails(localPosition: Offset.zero)),
            stubResponse,
          );
          expect(tapCount, 0, reason: 'TapDown 은 게이트에서 무시되어 아직 발사 안 됨');

          callback(
            FlTapUpEvent(TapUpDetails(kind: PointerDeviceKind.touch)),
            stubResponse,
          );
          expect(tapCount, 1, reason: 'TapUp 에서 committed tap 으로 발사');
          expect(lastMonth, fixture[1].month);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );

    testWidgets('mobile 환경: TapDown + TapUp 호출 시 TapUp 에서만 onMonthTap 1회', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        var tapCount = 0;
        final fixture = _fixture();

        await tester.pumpWidget(
          _wrap(MonthlyBarChart(data: fixture, onMonthTap: (_) => tapCount++)),
        );

        final chart = tester.widget<BarChart>(find.byType(BarChart));
        final callback = chart.data.barTouchData.touchCallback!;
        final stubResponse = _stubResponseFor(chart, 0);

        callback(
          FlTapDownEvent(TapDownDetails(localPosition: Offset.zero)),
          stubResponse,
        );
        callback(
          FlTapUpEvent(TapUpDetails(kind: PointerDeviceKind.touch)),
          stubResponse,
        );

        expect(tapCount, 1, reason: 'mobile 에서도 TapUp 에서만 발사');
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets(
      'scroll/drag cancel (CustomScrollView): TapDown + TapCancel → onMonthTap 0회',
      (tester) async {
        var tapCount = 0;
        final fixture = _fixture();

        await tester.pumpWidget(
          _wrap(MonthlyBarChart(data: fixture, onMonthTap: (_) => tapCount++)),
        );

        final chart = tester.widget<BarChart>(find.byType(BarChart));
        final callback = chart.data.barTouchData.touchCallback!;
        final stubResponse = _stubResponseFor(chart, 1);

        // 사용자가 막대 위에서 세로 스크롤을 시작 → CustomScrollView 의 gesture
        // arena 가 pan 으로 승격 → fl_chart 는 FlTapCancelEvent 를 emit.
        callback(
          FlTapDownEvent(TapDownDetails(localPosition: Offset.zero)),
          stubResponse,
        );
        callback(const FlTapCancelEvent(), null);

        expect(
          tapCount,
          0,
          reason:
              'CustomScrollView 안에서 스크롤 시작 → 토글이 발사되면 안 됨 '
              '(v3.1 Option B 에서 보고된 Codex HIGH 회귀)',
        );
      },
    );
  });
}
