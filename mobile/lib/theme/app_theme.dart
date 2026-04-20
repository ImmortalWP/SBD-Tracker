import 'package:flutter/material.dart';

class AppTheme {
  static const Color bg950 = Color(0xFF0a0a0b);
  static const Color bg900 = Color(0xFF18181b);
  static const Color bg850 = Color(0xFF1e1e22);
  static const Color bg800 = Color(0xFF27272a);
  static const Color bg700 = Color(0xFF3f3f46);
  static const Color bg600 = Color(0xFF52525b);
  static const Color text50 = Color(0xFFfafafa);
  static const Color text100 = Color(0xFFf4f4f5);
  static const Color text200 = Color(0xFFe4e4e7);
  static const Color text300 = Color(0xFFd4d4d8);
  static const Color text400 = Color(0xFFa1a1aa);
  static const Color text500 = Color(0xFF71717a);
  static const Color text600 = Color(0xFF52525b);
  static const Color text700 = Color(0xFF3f3f46);
  static const Color accentRed = Color(0xFFef4444);
  static const Color accentAmber = Color(0xFFf59e0b);
  static const Color accentGreen = Color(0xFF22c55e);
  static const Color accentBlue = Color(0xFF3b82f6);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg950,
      primaryColor: accentRed,
      colorScheme: const ColorScheme.dark(
        primary: accentRed,
        secondary: accentAmber,
        surface: bg850,
        error: accentRed,
      ),
      fontFamily: 'Inter',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w800,
          fontSize: 20,
          color: text50,
        ),
        iconTheme: IconThemeData(color: text400),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: bg900,
        selectedItemColor: accentRed,
        unselectedItemColor: text500,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 11),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bg900,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: bg700),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: bg700),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: accentRed.withValues(alpha: 0.6)),
        ),
        labelStyle: const TextStyle(color: text400, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5),
        hintStyle: const TextStyle(color: text500, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentRed,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
      cardTheme: CardThemeData(
        color: bg850,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: bg800),
        ),
        margin: EdgeInsets.zero,
      ),
    );
  }
}
