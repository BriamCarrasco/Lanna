// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

abstract final class LannaColors {
  static const Color bg = Color(0xFF0D0D10);
  static const Color surface = Color(0xFF17161B);
  static const Color surfaceHigh = Color(0xFF1C1B21);
  static const Color surfaceActive = Color(0xFF26242C);
  static const Color border = Color(0xFF2A2831);
  static const Color borderSubtle = Color(0xFF211F27);

  static const Color text = Color(0xFFE9E4DA);
  static const Color textStrong = Color(0xFFF4EFE5);
  static const Color textMuted = Color(0xFF8B8579);

  static const Color accent = Color(0xFFD9756A);
  static const Color accentStrong = Color(0xFFE8968D);
  static const Color success = Color(0xFF6FAE86);
}

abstract final class AppFonts {
  static const String ui = 'Manrope';

  static const String serif = 'Newsreader';
}

abstract final class AppTheme {
  static TextStyle reading({
    double? fontSize,
    double? height,
    FontWeight? fontWeight,
    Color? color,
  }) => TextStyle(
    fontFamily: AppFonts.serif,
    fontSize: fontSize,
    height: height,
    fontWeight: fontWeight,
    color: color,
  );

  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      primary: LannaColors.accent,
      onPrimary: LannaColors.surface,
      secondary: LannaColors.accentStrong,
      onSecondary: LannaColors.surface,
      surface: LannaColors.surface,
      onSurface: LannaColors.text,
      surfaceContainerLowest: LannaColors.bg,
      surfaceContainerLow: LannaColors.surface,
      surfaceContainer: LannaColors.surfaceHigh,
      surfaceContainerHigh: LannaColors.surfaceHigh,
      surfaceContainerHighest: LannaColors.surfaceActive,
      onSurfaceVariant: LannaColors.textMuted,
      outline: LannaColors.border,
      outlineVariant: LannaColors.borderSubtle,
      error: Color(0xFFE5686B),
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      fontFamily: AppFonts.ui,
      scaffoldBackgroundColor: LannaColors.bg,
    );

    return base.copyWith(
      textTheme: _serifHeadlines(base.textTheme),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        backgroundColor: LannaColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(
        color: LannaColors.border,
        thickness: 1,
        space: 1,
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: LannaColors.surfaceHigh,
        indicatorColor: LannaColors.surfaceActive,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: LannaColors.accent,
          foregroundColor: LannaColors.surface,
          textStyle: const TextStyle(
            fontFamily: AppFonts.ui,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(seedColor: LannaColors.accent),
      fontFamily: AppFonts.ui,
    );
    return base.copyWith(textTheme: _serifHeadlines(base.textTheme));
  }

  static TextTheme _serifHeadlines(TextTheme base) => base.copyWith(
    displayLarge: base.displayLarge?.copyWith(fontFamily: AppFonts.serif),
    displayMedium: base.displayMedium?.copyWith(fontFamily: AppFonts.serif),
    displaySmall: base.displaySmall?.copyWith(fontFamily: AppFonts.serif),
    headlineMedium: base.headlineMedium?.copyWith(
      fontFamily: AppFonts.serif,
      fontWeight: FontWeight.w600,
    ),
    headlineSmall: base.headlineSmall?.copyWith(
      fontFamily: AppFonts.serif,
      fontWeight: FontWeight.w600,
    ),
    titleLarge: base.titleLarge?.copyWith(
      fontFamily: AppFonts.serif,
      fontWeight: FontWeight.w600,
    ),
  );
}
