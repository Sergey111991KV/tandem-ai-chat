import 'package:flutter/material.dart';

import 'tandem_colors.dart';

abstract final class TandemTheme {
  static ThemeData dark() {
    const radius = 14.0;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: TandemColors.bg,
      colorScheme: const ColorScheme.dark(
        primary: TandemColors.accent,
        onPrimary: Colors.white,
        secondary: TandemColors.accentStrong,
        surface: TandemColors.bgCard,
        onSurface: TandemColors.text,
        outline: TandemColors.border,
        error: TandemColors.danger,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: TandemColors.bgElevated,
        foregroundColor: TandemColors.text,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: TandemColors.bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: const BorderSide(color: TandemColors.border),
        ),
      ),
      dividerTheme: const DividerThemeData(color: TandemColors.border),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: TandemColors.bgElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: TandemColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: TandemColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: TandemColors.accent, width: 1.5),
        ),
        hintStyle: const TextStyle(color: TandemColors.textMuted),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: TandemColors.bgElevated,
        selectedIconTheme: IconThemeData(color: TandemColors.accent),
        selectedLabelTextStyle: TextStyle(color: TandemColors.accent),
        unselectedIconTheme: IconThemeData(color: TandemColors.textMuted),
        unselectedLabelTextStyle: TextStyle(color: TandemColors.textMuted),
        indicatorColor: Color(0x284DA3FF),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: TandemColors.accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: TandemColors.text,
          side: const BorderSide(color: TandemColors.border),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontWeight: FontWeight.w700,
          color: TandemColors.text,
        ),
        titleMedium: TextStyle(
          fontWeight: FontWeight.w600,
          color: TandemColors.text,
        ),
        bodyMedium: TextStyle(color: TandemColors.text),
        bodySmall: TextStyle(color: TandemColors.textMuted),
      ),
    );
  }
}
