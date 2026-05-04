import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// buylog warm-neutral palette — 아이보리 + 테라코타 + 세이지 모스.
///
/// 디자인 핸드오프 `tokens.js`의 `warm` 팔레트 매핑.
/// **식별자는 develop 시점과 동일**하게 유지 — 모든 화면이 토큰 경유로 색을
/// 사용하므로 이 파일만 바꾸면 자동으로 새 팔레트가 적용된다. 자세한 변경
/// 의도는 `docs/REDESIGN_NOTES.md` 참고.
class AppColors {
  // Brand — terracotta ("정돈된 도구" 톤)
  static const primary = Color(0xFFC25A4A);
  static const primaryDark = Color(0xFFA0432F);
  static const primaryLight = Color(0xFFE89B8C);
  // 기존 코드가 참조하는 "primary 위 약한 틴트" 슬롯. 디자인의 primarySoft에 매핑.
  static const primaryLight2 = Color(0xFFF2DDD4);

  // Surfaces — bone cream + ivory
  static const background = Color(0xFFF7F2E9);
  static const surface = Color(0xFFFBF8F1);
  static const surfaceAlt = Color(0xFFEFE8DA);

  // Ink ramp (text → textSecondary → textMuted → textSoft 순으로 옅어짐)
  static const text = Color(0xFF2A2620);
  static const textSecondary = Color(0xFF5C544A);
  static const textMuted = Color(0xFF8E8472);
  static const textSoft = Color(0xFFB5AC97);

  // Hairlines
  static const border = Color(0xFFDCD3BF);

  // Status — warm-tier values, 동일 식별자
  static const success = Color(0xFF5A8A6B);
  static const successLight = Color(0xFFD8E5DA);
  static const warning = Color(0xFFB98430);
  static const warningLight = Color(0xFFF2E2C0);
  static const danger = Color(0xFFB0392E);
  static const dangerLight = Color(0xFFF6D5CD);
}

class AppTheme {
  static ThemeData get lightTheme {
    final textTheme = GoogleFonts.notoSansTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        surface: AppColors.surface,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: AppColors.background,
      textTheme: textTheme.copyWith(
        headlineLarge: textTheme.headlineLarge?.copyWith(
          color: AppColors.text,
          fontWeight: FontWeight.w700,
          fontSize: 28,
          letterSpacing: -0.8,
        ),
        headlineMedium: textTheme.headlineMedium?.copyWith(
          color: AppColors.text,
          fontWeight: FontWeight.w700,
          fontSize: 22,
          letterSpacing: -0.6,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          color: AppColors.text,
          fontWeight: FontWeight.w700,
          fontSize: 17,
          letterSpacing: -0.3,
        ),
        titleMedium: textTheme.titleMedium?.copyWith(
          color: AppColors.text,
          fontWeight: FontWeight.w600,
          fontSize: 15,
          letterSpacing: -0.2,
        ),
        bodyLarge: textTheme.bodyLarge?.copyWith(
          color: AppColors.text,
          fontSize: 15,
        ),
        bodyMedium: textTheme.bodyMedium?.copyWith(
          color: AppColors.textSecondary,
          fontSize: 13.5,
        ),
        bodySmall: textTheme.bodySmall?.copyWith(
          color: AppColors.textMuted,
          fontSize: 12,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border, width: 0.5),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.notoSans(
          color: AppColors.text,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        iconTheme: const IconThemeData(color: AppColors.text),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.1,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
