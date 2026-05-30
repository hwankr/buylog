import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:buylog/services/report_service.dart';
import 'package:buylog/theme/app_theme.dart';
import 'package:buylog/widgets/reports/report_palette.dart';

void main() {
  group('ReportPalette', () {
    test(
      'returns explicit chart colors for selected, latest, idle, and empty bars',
      () {
        expect(
          ReportPalette.barColor(
            isSelected: true,
            isLatest: false,
            hasValue: true,
          ),
          AppColors.primaryDark,
        );
        expect(
          ReportPalette.barColor(
            isSelected: false,
            isLatest: true,
            hasValue: true,
          ),
          AppColors.primary,
        );
        expect(
          ReportPalette.barColor(
            isSelected: false,
            isLatest: false,
            hasValue: true,
          ),
          const Color(0xFFC57868),
        );
        expect(
          ReportPalette.barColor(
            isSelected: false,
            isLatest: false,
            hasValue: false,
          ),
          AppColors.surfaceAlt,
        );
      },
    );

    test('maps report categories to warm palette colors', () {
      expect(ReportPalette.categoryColor('욕실/위생'), const Color(0xFF4D8B8C));
      expect(ReportPalette.categoryColor('가전/필터'), AppColors.success);
      expect(ReportPalette.categoryColor('세탁/청소'), AppColors.warning);
      expect(ReportPalette.categoryColor('주방/세제'), const Color(0xFF8B5E83));
      expect(ReportPalette.categoryColor('헤어/바디'), AppColors.danger);
      expect(ReportPalette.categoryColor('알 수 없음'), AppColors.textSecondary);
    });

    test('maps insight kinds to distinct semantic colors', () {
      expect(
        ReportPalette.insightColor(ReportInsightKind.refill),
        AppColors.success,
      );
      expect(
        ReportPalette.insightColor(ReportInsightKind.spending),
        AppColors.primaryDark,
      );
      expect(
        ReportPalette.insightColor(ReportInsightKind.price),
        AppColors.warning,
      );
    });
  });
}
