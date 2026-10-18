import 'package:flutter/material.dart';

/// 波奇酱粉色主题
class BocchiTheme {
  static const Color pink = Color(0xFFF48FB1);
  static const Color pinkDeep = Color(0xFFEC407A);
  static const Color pinkLight = Color(0xFFFCE4EC);
  static const Color pinkPale = Color(0xFFFFF6F9);
  static const Color ink = Color(0xFF4A3540);
  static const Color inkSoft = Color(0xFF8A6D7A);
  static const Color okGreen = Color(0xFF43A047);
  static const Color warnRed = Color(0xFFE53935);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: pink,
      primary: pinkDeep,
      surface: Colors.white,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme.copyWith(
        primary: pinkDeep,
        secondary: pink,
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: pinkPale,
      appBarTheme: const AppBarTheme(
        backgroundColor: pinkDeep,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shadowColor: pink.withValues(alpha: 0.25),
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: pinkLight, width: 1),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: pinkDeep,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: pinkDeep,
        unselectedItemColor: inkSoft,
        backgroundColor: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: pinkLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: pinkLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: pinkDeep, width: 1.6),
        ),
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: ink),
        bodySmall: TextStyle(color: inkSoft),
        titleMedium: TextStyle(color: ink, fontWeight: FontWeight.w600),
      ),
    );
  }
}
