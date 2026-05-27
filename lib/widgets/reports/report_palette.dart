import 'package:flutter/material.dart';

import '../../services/report_service.dart';
import '../../theme/app_theme.dart';

class ReportPalette {
  static const chartIdle = Color(0xFFC57868);
  static const chartGrid = Color(0xFFE7DDCC);

  static const hygiene = Color(0xFF4D8B8C);
  static const kitchen = Color(0xFF8B5E83);

  static const Map<String, Color> categoryColors = <String, Color>{
    '위생': hygiene,
    '욕실/위생': hygiene,
    '필터': AppColors.success,
    '가전/필터': AppColors.success,
    '세탁': AppColors.warning,
    '세탁/청소': AppColors.warning,
    '주방': kitchen,
    '주방/세제': kitchen,
    '헤어/바디': AppColors.danger,
    '기타': AppColors.textSecondary,
  };

  static Color barColor({
    required bool isSelected,
    required bool isLatest,
    required bool hasValue,
  }) {
    if (!hasValue) return AppColors.surfaceAlt;
    if (isSelected) return AppColors.primaryDark;
    if (isLatest) return AppColors.primary;
    return chartIdle;
  }

  static Color categoryColor(String name) =>
      categoryColors[name] ?? AppColors.textSecondary;

  static Color categoryTint(String name, {double alpha = 0.12}) =>
      categoryColor(name).withValues(alpha: alpha);

  static Color insightColor(ReportInsightKind kind) {
    return switch (kind) {
      ReportInsightKind.refill => AppColors.success,
      ReportInsightKind.spending => AppColors.primaryDark,
      ReportInsightKind.price => AppColors.warning,
    };
  }

  static Color insightSurface(ReportInsightKind kind) {
    return Color.alphaBlend(
      insightColor(kind).withValues(alpha: 0.12),
      AppColors.surface,
    );
  }
}

Color colorForCategory(String name) => ReportPalette.categoryColor(name);
