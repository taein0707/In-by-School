import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';

/// Builds WDS-flavoured [ThemeData]. Calm, white-based, single accent.
class AppTheme {
  AppTheme._();

  static ThemeData light({Color? accent}) =>
      _build(Brightness.light, AppColors.light(accent: accent ?? const Color(0xFF0066FF)));

  static ThemeData dark({Color? accent}) =>
      _build(Brightness.dark, AppColors.dark(accent: accent ?? const Color(0xFF3385FF)));

  static ThemeData _build(Brightness b, AppColors c) {
    final base = ThemeData(brightness: b, useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: c.bg,
      colorScheme: base.colorScheme.copyWith(
        brightness: b,
        primary: c.accent,
        surface: c.bg,
        error: c.negative,
      ),
      extensions: [c],
      splashFactory: InkRipple.splashFactory,
      textTheme: _textTheme(c.labelNormal),
      textSelectionTheme: TextSelectionThemeData(cursorColor: c.accent, selectionColor: c.accentSoft),
      iconTheme: IconThemeData(color: c.labelNeutral),
    );
  }

  static TextTheme _textTheme(Color color) => TextTheme(
        displayLarge: AppType.display3.copyWith(color: color),
        headlineLarge: AppType.title1.copyWith(color: color),
        headlineMedium: AppType.title2.copyWith(color: color),
        headlineSmall: AppType.title3.copyWith(color: color),
        titleLarge: AppType.heading1.copyWith(color: color),
        titleMedium: AppType.heading2.copyWith(color: color),
        bodyLarge: AppType.body1.copyWith(color: color),
        bodyMedium: AppType.body2.copyWith(color: color),
        labelLarge: AppType.label1.copyWith(color: color),
        labelMedium: AppType.label2.copyWith(color: color),
        labelSmall: AppType.caption1.copyWith(color: color),
      );
}
