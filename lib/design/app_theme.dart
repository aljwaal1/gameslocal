import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFFF2F6F3);
  static const surface = Color(0xFFFFFFFF);
  static const primary = Color(0xFF1F6F63);
  static const primaryDark = Color(0xFF12463F);
  static const accent = Color(0xFFFFC857);
  static const danger = Color(0xFFC84C4C);
  static const ink = Color(0xFF17211F);
  static const muted = Color(0xFF687875);
  static const boardDark = Color(0xFF56736D);
  static const boardLight = Color(0xFFE8EFEA);
}

class AppThemeFactory {
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.ink,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
      ),
    );
  }
}
