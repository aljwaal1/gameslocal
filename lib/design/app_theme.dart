import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFFF2F5FA);
  static const backgroundWarm = Color(0xFFFFFBF5);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceSoft = Color(0xFFF8FAFC);
  static const primary = Color(0xFF0F766E);
  static const primaryDark = Color(0xFF083D39);
  static const accent = Color(0xFFFFB703);
  static const accentSoft = Color(0xFFFFE8A3);
  static const secondary = Color(0xFF6D28D9);
  static const violet = Color(0xFF7C3AED);
  static const cyan = Color(0xFF0EA5E9);
  static const electricBlue = Color(0xFF2563EB);
  static const success = Color(0xFF16A34A);
  static const danger = Color(0xFFDC2626);
  static const orange = Color(0xFFF97316);
  static const rose = Color(0xFFE11D48);
  static const ink = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
  static const boardDark = Color(0xFF1F5D50);
  static const boardLight = Color(0xFFF0E5C9);
  static const navy = Color(0xFF07111F);
  static const line = Color(0x1A0F172A);

  static const heroGradient = <Color>[
    Color(0xFF075985),
    Color(0xFF0F766E),
    Color(0xFF6D28D9),
  ];
}

class GamePalette {
  const GamePalette(this.primary, this.secondary, this.glow);

  final Color primary;
  final Color secondary;
  final Color glow;

  static const football = GamePalette(
    Color(0xFF15803D),
    Color(0xFF0F766E),
    Color(0xFF86EFAC),
  );
  static const xo = GamePalette(
    Color(0xFFE11D48),
    Color(0xFF6D28D9),
    Color(0xFFFDA4AF),
  );
  static const checkers = GamePalette(
    Color(0xFF0F766E),
    Color(0xFFB45309),
    Color(0xFF5EEAD4),
  );
  static const domino = GamePalette(
    Color(0xFFEA580C),
    Color(0xFF7C3AED),
    Color(0xFFFDBA74),
  );
  static const chess = GamePalette(
    Color(0xFF1E293B),
    Color(0xFFB68A2C),
    Color(0xFFFDE68A),
  );
  static const cards = GamePalette(
    Color(0xFF047857),
    Color(0xFFBE123C),
    Color(0xFF6EE7B7),
  );
  static const words = GamePalette(
    Color(0xFF7C3AED),
    Color(0xFF2563EB),
    Color(0xFFC4B5FD),
  );
  static const sheikh = GamePalette(
    Color(0xFF1D4ED8),
    Color(0xFFB68A2C),
    Color(0xFF93C5FD),
  );
  static const boxes = GamePalette(
    Color(0xFF0891B2),
    Color(0xFF7C3AED),
    Color(0xFF67E8F9),
  );
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
      onSurface: AppColors.ink,
    );

    final rounded16 = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        backgroundColor: Color(0xFFF8FAFC),
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: AppColors.ink, size: 23),
        actionsIconTheme: IconThemeData(color: AppColors.ink, size: 23),
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
        shadowColor: const Color(0x260F172A),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.line),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: const Color(0x330F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        titleTextStyle: const TextStyle(
          color: AppColors.ink,
          fontSize: 21,
          fontWeight: FontWeight.w900,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: const Color(0x550F766E),
          shape: rounded16,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          minimumSize: const Size(48, 48),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 15,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 2,
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.ink,
          shadowColor: const Color(0x260F172A),
          surfaceTintColor: Colors.transparent,
          shape: rounded16,
          minimumSize: const Size(48, 48),
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryDark,
          side: const BorderSide(color: Color(0x660F766E), width: 1.2),
          shape: rounded16,
          minimumSize: const Size(48, 48),
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryDark,
          shape: rounded16,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
        hintStyle: const TextStyle(color: AppColors.muted),
        labelStyle: const TextStyle(
          color: AppColors.muted,
          fontWeight: FontWeight.w700,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: const BorderSide(color: AppColors.cyan, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.accentSoft,
        side: const BorderSide(color: AppColors.line),
        labelStyle: const TextStyle(
          color: AppColors.ink,
          fontWeight: FontWeight.w800,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.navy,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.all(14),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: AppColors.surface,
        showDragHandle: true,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.accentSoft,
        elevation: 0,
        height: 68,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.ink,
          backgroundColor: const Color(0x0D0F172A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.line,
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: Color(0x190F766E),
      ),
      dividerColor: AppColors.line,
    );
  }
}
