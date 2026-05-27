import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/dday_format.dart';

class DdayBadge extends StatelessWidget {
  final int daysRemaining;
  final double fontSize;

  const DdayBadge({super.key, required this.daysRemaining, this.fontSize = 12});

  Color get _backgroundColor {
    if (daysRemaining <= 3) return AppColors.dangerLight;
    if (daysRemaining <= 7) return AppColors.warningLight;
    if (daysRemaining <= 14) return AppColors.primaryLight2;
    return AppColors.successLight;
  }

  Color get _textColor {
    if (daysRemaining <= 3) return AppColors.danger;
    if (daysRemaining <= 7) return AppColors.warning;
    if (daysRemaining <= 14) return AppColors.primary;
    return AppColors.success;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        formatDdayLabel(daysRemaining),
        style: TextStyle(
          color: _textColor,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
