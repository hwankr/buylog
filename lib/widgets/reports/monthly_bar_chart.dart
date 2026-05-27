import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../services/report_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/price_format.dart';
import 'report_palette.dart';

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

  double _barWidthFor(int count) => count > 8 ? 18 : 24;

  String _axisPriceLabel(double value) {
    if (value <= 0) return '';
    if (value >= 10000) return '${(value / 10000).round()}만';
    return value.round().toString();
  }

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
            horizontalInterval: computedMaxY / 4,
            getDrawingHorizontalLine: (value) =>
                const FlLine(color: ReportPalette.chartGrid, strokeWidth: 0.5),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: computedMaxY / 2,
                getTitlesWidget: (value, meta) {
                  final label = _axisPriceLabel(value);
                  if (label.isEmpty) return const SizedBox.shrink();
                  return Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < data.length) {
                    final isLatest = index == data.length - 1;
                    final isSelected =
                        selectedMonth != null &&
                        data[index].month == selectedMonth;
                    final highlighted =
                        isSelected || (highlightLatest && isLatest);
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '${data[index].month.month}월',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: highlighted
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: highlighted
                              ? AppColors.primaryDark
                              : AppColors.textSecondary,
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
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppColors.text,
              tooltipBorderRadius: BorderRadius.circular(8),
              tooltipPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              fitInsideHorizontally: true,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final month = data[group.x.toInt()].month;
                final amount = data[group.x.toInt()].totalAmount;
                return BarTooltipItem(
                  '${month.month}월\n${formatPrice(amount)}',
                  const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                );
              },
            ),
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
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: entry.value.totalAmount.toDouble(),
                  width: _barWidthFor(data.length),
                  color: ReportPalette.barColor(
                    isSelected: isSelected,
                    isLatest: highlightLatest && isLatest,
                    hasValue: entry.value.totalAmount > 0,
                  ),
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
