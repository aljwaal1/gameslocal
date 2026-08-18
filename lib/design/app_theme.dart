import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFFF4F7FB);
  static const surface = Color(0xFFFFFFFF);
  static const primary = Color(0xFF0F766E);
  static const primaryDark = Color(0xFF083D39);
  static const accent = Color(0xFFFFB703);
  static const accentSoft = Color(0xFFFFE8A3);
  static const secondary = Color(0xFF6D28D9);
  static const cyan = Color(0xFF0EA5E9);
  static const success = Color(0xFF16A34A);
  static const danger = Color(0xFFDC2626);
  static const ink = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
  static const boardDark = Color(0xFF1F5D50);
  static const boardLight = Color(0xFFF0E5C9);
  static const navy = Color(0xFF0B1220);
}

class AppThemeFactory {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      tertiary: AppColors.accent,
      error: AppColors.danger,
      surface: AppColors.surface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        backgroundColor: Color(0xFFF9FBFD),
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: AppColors.ink,
          fontSize: 20,
          fontWeight: FontWeight.w900,
          letterSpacing: .1,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: const Color(0x220F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: Color(0x140F172A)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 1,
          shadowColor: const Color(0x440F766E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryDark,
          side: const BorderSide(color: Color(0x550F766E)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0x220F172A)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0x220F172A)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.cyan, width: 2),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: AppColors.accentSoft,
        side: const BorderSide(color: Color(0x180F172A)),
        labelStyle: const TextStyle(
          color: AppColors.ink,
          fontWeight: FontWeight.w800,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerColor: const Color(0x180F172A),
    );
  }
}
