import 'package:flutter/material.dart';

/// Unified color palette for the SBD Tracker app.
/// All screens should import this instead of defining local color constants.
class AppColors {
  AppColors._();

  // ─── Backgrounds ───
  static const Color bg = Color(0xFF090D14);
  static const Color cardBg = Color(0xFF151923);
  static const Color inputBg = Color(0xFF11141D);
  static const Color borderColor = Color(0xFF222836);

  // ─── Text ───
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF475569);

  // ─── Accents ───
  static const Color accentBlue = Color(0xFF2563EB);
  static const Color accentBlueLight = Color(0xFF3B82F6);
  static const Color accentBlueBg = Color(0xFF172554);
  static const Color accentGreen = Color(0xFF22C55E);
  static const Color accentRed = Color(0xFFEF4444);

  // ─── Stats (Sessions Screen) ───
  static const Color statYellow = Color(0xFFEAB308);
  static const Color statPurple = Color(0xFFA855F7);
}
