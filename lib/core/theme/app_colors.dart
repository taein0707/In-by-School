import 'package:flutter/material.dart';

/// WDS semantic color tokens exposed as a [ThemeExtension].
/// White-based, single blue accent. Light is default; [dark] mirrors it.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color labelStrong;
  final Color labelNormal;
  final Color labelNeutral;
  final Color labelAlt;
  final Color labelAssistive;

  final Color bg; // page
  final Color bgAlt; // subtle surface
  final Color bgElevated; // cards / sheets

  final Color fill;
  final Color fillStrong;
  final Color line;
  final Color lineAlt;

  final Color accent; // brand blue
  final Color accentSoft; // tinted container

  final Color positive;
  final Color cautionary;
  final Color negative;

  const AppColors({
    required this.labelStrong,
    required this.labelNormal,
    required this.labelNeutral,
    required this.labelAlt,
    required this.labelAssistive,
    required this.bg,
    required this.bgAlt,
    required this.bgElevated,
    required this.fill,
    required this.fillStrong,
    required this.line,
    required this.lineAlt,
    required this.accent,
    required this.accentSoft,
    required this.positive,
    required this.cautionary,
    required this.negative,
  });

  static const Color _blue = Color(0xFF0066FF);

  factory AppColors.light({Color accent = _blue}) => AppColors(
        labelStrong: const Color(0xFF000000),
        labelNormal: const Color(0xFF171717),
        labelNeutral: const Color.fromRGBO(46, 47, 51, 0.88),
        labelAlt: const Color.fromRGBO(55, 56, 60, 0.61),
        labelAssistive: const Color.fromRGBO(55, 56, 60, 0.28),
        bg: const Color(0xFFFFFFFF),
        bgAlt: const Color(0xFFF7F7F8),
        bgElevated: const Color(0xFFFFFFFF),
        fill: const Color.fromRGBO(112, 115, 124, 0.08),
        fillStrong: const Color.fromRGBO(112, 115, 124, 0.16),
        line: const Color.fromRGBO(112, 115, 124, 0.22),
        lineAlt: const Color.fromRGBO(112, 115, 124, 0.08),
        accent: accent,
        accentSoft: Color.alphaBlend(accent.withValues(alpha: 0.10), Colors.white),
        positive: const Color(0xFF00BF40),
        cautionary: const Color(0xFFFF9200),
        negative: const Color(0xFFFF4242),
      );

  factory AppColors.dark({Color accent = const Color(0xFF3385FF)}) => AppColors(
        labelStrong: const Color(0xFFFFFFFF),
        labelNormal: const Color(0xFFF7F7F7),
        labelNeutral: const Color.fromRGBO(194, 196, 200, 0.88),
        labelAlt: const Color.fromRGBO(174, 176, 182, 0.61),
        labelAssistive: const Color.fromRGBO(174, 176, 182, 0.28),
        bg: const Color(0xFF1B1C1E),
        bgAlt: const Color(0xFF0F0F10),
        bgElevated: const Color(0xFF212225),
        fill: const Color.fromRGBO(112, 115, 124, 0.22),
        fillStrong: const Color.fromRGBO(112, 115, 124, 0.28),
        line: const Color.fromRGBO(112, 115, 124, 0.32),
        lineAlt: const Color.fromRGBO(112, 115, 124, 0.22),
        accent: accent,
        accentSoft: Color.alphaBlend(accent.withValues(alpha: 0.16), const Color(0xFF1B1C1E)),
        positive: const Color(0xFF1ED45A),
        cautionary: const Color(0xFFFFA938),
        negative: const Color(0xFFFF6363),
      );

  @override
  AppColors copyWith({Color? accent}) => AppColors(
        labelStrong: labelStrong,
        labelNormal: labelNormal,
        labelNeutral: labelNeutral,
        labelAlt: labelAlt,
        labelAssistive: labelAssistive,
        bg: bg,
        bgAlt: bgAlt,
        bgElevated: bgElevated,
        fill: fill,
        fillStrong: fillStrong,
        line: line,
        lineAlt: lineAlt,
        accent: accent ?? this.accent,
        accentSoft: accentSoft,
        positive: positive,
        cautionary: cautionary,
        negative: negative,
      );

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      labelStrong: Color.lerp(labelStrong, other.labelStrong, t)!,
      labelNormal: Color.lerp(labelNormal, other.labelNormal, t)!,
      labelNeutral: Color.lerp(labelNeutral, other.labelNeutral, t)!,
      labelAlt: Color.lerp(labelAlt, other.labelAlt, t)!,
      labelAssistive: Color.lerp(labelAssistive, other.labelAssistive, t)!,
      bg: Color.lerp(bg, other.bg, t)!,
      bgAlt: Color.lerp(bgAlt, other.bgAlt, t)!,
      bgElevated: Color.lerp(bgElevated, other.bgElevated, t)!,
      fill: Color.lerp(fill, other.fill, t)!,
      fillStrong: Color.lerp(fillStrong, other.fillStrong, t)!,
      line: Color.lerp(line, other.line, t)!,
      lineAlt: Color.lerp(lineAlt, other.lineAlt, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      positive: Color.lerp(positive, other.positive, t)!,
      cautionary: Color.lerp(cautionary, other.cautionary, t)!,
      negative: Color.lerp(negative, other.negative, t)!,
    );
  }
}

/// Quick access: `context.c.accent`.
extension AppColorsX on BuildContext {
  AppColors get c => Theme.of(this).extension<AppColors>()!;
}
