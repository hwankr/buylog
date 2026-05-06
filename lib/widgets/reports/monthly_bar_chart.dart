import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../services/report_service.dart';
import '../../theme/app_theme.dart';

/// 월별 지출 막대 차트.
class MonthlyBarChart extends StatelessWidget {
  const MonthlyBarChart({
    super.key,
    required this.data,
    this.onMonthTap,
    this.selectedMonth,
    this.highlightLatest = true,
  });

  final List<MonthlySpending> data;
  final void Function(DateTime month)? onMonthTap;
  final DateTime? selectedMonth;
  final bool highlightLatest;

  @override
  Widget build(BuildContext context) {
    final maxTotal = data.isEmpty
        ? 0
        : data.map((e) => e.totalAmount).reduce((a, b) => a > b ? a : b);
    final rounded = ((maxTotal / 10000).ceil() * 10000).toDouble();
    final computedMaxY = rounded < 160000.0 ? 160000.0 : rounded;

    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: computedMaxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 50000,
            getDrawingHorizontalLine: (value) =>
                FlLine(color: AppColors.border, strokeWidth: 0.5),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < data.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '${data[index].month.month}월',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            enabled: true,
            touchCallback: (event, response) {
              // fl_chart 1.2.0 은 desktop/web 에서 한 번의 탭에 FlTapDownEvent +
              // FlTapUpEvent 둘 다 emit 한다. 본 차트는 CustomScrollView 안에
              // 배치되므로 TapDown 에서 커밋하면 사용자가 세로 스크롤을 시작한
              // 경우에도 토글이 발사된다 (gesture arena 가 pan 으로 승격되면
              // FlTapCancelEvent 가 뒤따르지만 이미 setState 는 호출된 후).
              // 따라서 committed tap 인 FlTapUpEvent 만 통과시킨다.
              // render_base_chart.dart:94-96 기준 TapUp 은 모든 플랫폼에서
              // 1회만 emit 되므로 단일 발화 보장 (데스크톱 이중 발화 회피는
              // 이 가드가 TapDown 을 차단하는 것으로 자동 해결).
              // 스크롤/드래그 취소 시에는 TapUp 대신 FlTapCancelEvent 가
              // 와서 이 가드에서 무시된다.
              if (event is! FlTapUpEvent) return;
              if (response == null || response.spot == null) return;
              final index = response.spot!.touchedBarGroupIndex;
              if (index < 0 || index >= data.length) return;
              onMonthTap?.call(data[index].month);
            },
          ),
          barGroups: data.asMap().entries.map((entry) {
            final isLatest = entry.key == data.length - 1;
            final isSelected =
                selectedMonth != null && entry.value.month == selectedMonth;
            final highlighted = isSelected || (highlightLatest && isLatest);
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: entry.value.totalAmount.toDouble(),
                  width: 28,
                  color: highlighted
                      ? AppColors.primary
                      : AppColors.primary.withValues(alpha: 0.3),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(6),
                    topRight: Radius.circular(6),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
