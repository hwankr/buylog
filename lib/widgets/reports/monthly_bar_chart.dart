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
  });

  final List<MonthlySpending> data;
  final void Function(DateTime month)? onMonthTap;
  final DateTime? selectedMonth;

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
              if (!event.isInterestedForInteractions) return;
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
            final highlighted = isSelected || isLatest;
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: entry.value.totalAmount.toDouble(),
                  width: 28,
                  color: highlighted
                      ? AppColors.primary
                      : AppColors.primary.withOpacity(0.3),
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
