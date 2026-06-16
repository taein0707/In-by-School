import 'package:flutter/material.dart';

/// WDS type scale in Pretendard. Sizes/heights/spacing match the design
/// tokens (letter-spacing converted from em to logical px). Colors are left
/// null so they inherit from the surrounding [DefaultTextStyle]/theme.
class AppType {
  AppType._();
  static const String family = 'Pretendard';

  static const TextStyle display3 = TextStyle(
      fontFamily: family, fontSize: 36, height: 48 / 36, fontWeight: FontWeight.w700, letterSpacing: -0.97);
  static const TextStyle title1 = TextStyle(
      fontFamily: family, fontSize: 32, height: 44 / 32, fontWeight: FontWeight.w700, letterSpacing: -0.81);
  static const TextStyle title2 = TextStyle(
      fontFamily: family, fontSize: 28, height: 38 / 28, fontWeight: FontWeight.w700, letterSpacing: -0.66);
  static const TextStyle title3 = TextStyle(
      fontFamily: family, fontSize: 24, height: 32 / 24, fontWeight: FontWeight.w600, letterSpacing: -0.55);
  static const TextStyle heading1 = TextStyle(
      fontFamily: family, fontSize: 22, height: 30 / 22, fontWeight: FontWeight.w600, letterSpacing: -0.43);
  static const TextStyle heading2 = TextStyle(
      fontFamily: family, fontSize: 20, height: 28 / 20, fontWeight: FontWeight.w600, letterSpacing: -0.24);
  static const TextStyle headline1 = TextStyle(
      fontFamily: family, fontSize: 18, height: 26 / 18, fontWeight: FontWeight.w600, letterSpacing: -0.04);
  static const TextStyle headline2 = TextStyle(
      fontFamily: family, fontSize: 17, height: 24 / 17, fontWeight: FontWeight.w600);
  static const TextStyle body1 = TextStyle(
      fontFamily: family, fontSize: 16, height: 24 / 16, fontWeight: FontWeight.w400, letterSpacing: 0.09);
  static const TextStyle body2 = TextStyle(
      fontFamily: family, fontSize: 15, height: 22 / 15, fontWeight: FontWeight.w400, letterSpacing: 0.14);
  static const TextStyle label1 = TextStyle(
      fontFamily: family, fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w500, letterSpacing: 0.20);
  static const TextStyle label2 = TextStyle(
      fontFamily: family, fontSize: 13, height: 18 / 13, fontWeight: FontWeight.w500, letterSpacing: 0.25);
  static const TextStyle caption1 = TextStyle(
      fontFamily: family, fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w500, letterSpacing: 0.30);
  static const TextStyle caption2 = TextStyle(
      fontFamily: family, fontSize: 11, height: 14 / 11, fontWeight: FontWeight.w500, letterSpacing: 0.34);
}
