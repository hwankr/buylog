import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/dday_format.dart';

class CountdownRing extends StatelessWidget {
  final int daysRemaining;
  final int totalDays;
  final double size;

  const CountdownRing({
    super.key,
    required this.daysRemaining,
    required this.totalDays,
    this.size = 140,
  });

  Color get _ringColor {
    if (daysRemaining <= 3) return AppColors.danger;
    if (daysRemaining <= 7) return AppColors.warning;
    if (daysRemaining <= 14) return AppColors.primary;
    return AppColors.success;
  }

  @override
  Widget build(BuildContext context) {
    final progress = 1.0 - (daysRemaining / totalDays).clamp(0.0, 1.0);

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          progress: progress,
          color: _ringColor,
          backgroundColor: AppColors.border,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                formatDdayLabel(daysRemaining),
                style: TextStyle(
                  fontSize: size * 0.2,
                  fontWeight: FontWeight.w700,
                  color: _ringColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                formatDdayCaption(daysRemaining),
                style: TextStyle(
                  fontSize: size * 0.1,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;

  _RingPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const strokeWidth = 10.0;

    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      progress != oldDelegate.progress || color != oldDelegate.color;
}
