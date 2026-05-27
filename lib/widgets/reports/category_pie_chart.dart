import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../services/report_service.dart';
import '../../theme/app_theme.dart';
import 'report_palette.dart';

/// 카테고리명 → 표시 색상. 매핑이 없으면 muted 색상으로 폴백.
Color colorForCategory(String name) => ReportPalette.categoryColor(name);

/// 카테고리별 지출 도넛 차트 + 범례.
class CategoryPieChart extends StatelessWidget {
  const CategoryPieChart({super.key, required this.data});

  final List<CategoryBreakdown> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: Text(
            '데이터 없음',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        ),
      );
    }

    return SizedBox(
      height: 200,
      child: Row(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 45,
                sections: data.map((c) {
                  return PieChartSectionData(
                    value: c.ratio * 100,
                    color: colorForCategory(c.category),
                    radius: 35,
                    showTitle: false,
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: data.map((c) {
              final percent = (c.ratio * 100).round();
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: colorForCategory(c.category),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 72,
                      child: Text(
                        c.category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$percent%',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
