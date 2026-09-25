import 'package:flutter/material.dart';

/// SBD Tracker Design System
/// Inspired by clean, minimal fitness-tracking aesthetics.
/// Dark-first, data-dense, workout-focused.
class AppColors {
  AppColors._();

  // ─── Backgrounds ───
  static const Color bg = Color(0xFF0B0B0F);
  static const Color surfacePrimary = Color(0xFF101116);
  static const Color cardBg = Color(0xFF15151B);
  static const Color elevated = Color(0xFF1C1C24);
  static const Color inputBg = Color(0xFF101116);
  static const Color borderColor = Color(0xFF2A2A35);

  // ─── Text ───
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFFA1A1AA);
  static const Color textMuted = Color(0xFF71717A);

  // ─── Brand ───
  static const Color accentBlue = Color(0xFF3B82F6);
  static const Color accentBlueLight = Color(0xFF60A5FA);
  static const Color accentBlueBg = Color(0xFF172554);

  // ─── Semantic ───
  static const Color accentGreen = Color(0xFF22C55E);
  static const Color accentRed = Color(0xFFEF4444);
  static const Color accentAmber = Color(0xFFF59E0B);

  // ─── Stats ───
  static const Color statYellow = Color(0xFFEAB308);
  static const Color statPurple = Color(0xFFA855F7);
}

/// Consistent spacing tokens.
class Spacing {
  Spacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double base = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Corner radii tokens.
class Radii {
  Radii._();
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
}

/// Typography presets for consistent text hierarchy.
class AppTypography {
  AppTypography._();

  // ─── Display ─── (huge lift numbers)
  static const TextStyle displayLarge = TextStyle(
    fontSize: 36, fontWeight: FontWeight.w800,
    color: AppColors.textPrimary, height: 1.1,
    letterSpacing: -0.5,
  );
  static const TextStyle displayMedium = TextStyle(
    fontSize: 28, fontWeight: FontWeight.w800,
    color: AppColors.textPrimary, height: 1.15,
    letterSpacing: -0.3,
  );

  // ─── Headings ───
  static const TextStyle h1 = TextStyle(
    fontSize: 24, fontWeight: FontWeight.w700,
    color: AppColors.textPrimary, height: 1.2,
  );
  static const TextStyle h2 = TextStyle(
    fontSize: 20, fontWeight: FontWeight.w700,
    color: AppColors.textPrimary, height: 1.25,
  );
  static const TextStyle h3 = TextStyle(
    fontSize: 17, fontWeight: FontWeight.w600,
    color: AppColors.textPrimary, height: 1.3,
  );

  // ─── Body ───
  static const TextStyle body = TextStyle(
    fontSize: 15, fontWeight: FontWeight.w400,
    color: AppColors.textPrimary, height: 1.5,
  );
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14, fontWeight: FontWeight.w500,
    color: AppColors.textSecondary, height: 1.45,
  );
  static const TextStyle bodySmall = TextStyle(
    fontSize: 13, fontWeight: FontWeight.w400,
    color: AppColors.textSecondary, height: 1.4,
  );

  // ─── Labels ───
  static const TextStyle label = TextStyle(
    fontSize: 12, fontWeight: FontWeight.w600,
    color: AppColors.textMuted, height: 1.3,
    letterSpacing: 0.5,
  );
  static const TextStyle labelSmall = TextStyle(
    fontSize: 11, fontWeight: FontWeight.w500,
    color: AppColors.textMuted, height: 1.3,
    letterSpacing: 0.3,
  );

  // ─── Mono ─── (weights, numbers)
  static const TextStyle mono = TextStyle(
    fontSize: 15, fontWeight: FontWeight.w700,
    color: AppColors.textPrimary, height: 1.3,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const TextStyle monoLarge = TextStyle(
    fontSize: 22, fontWeight: FontWeight.w800,
    color: AppColors.textPrimary, height: 1.15,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  // ─── Section Headers ───
  static const TextStyle sectionHeader = TextStyle(
    fontSize: 12, fontWeight: FontWeight.w700,
    color: AppColors.textMuted, height: 1.3,
    letterSpacing: 0.8,
  );
}
