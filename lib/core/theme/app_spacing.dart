import 'package:flutter/material.dart';

/// WDS 4px spacing grid, radius scale, and soft elevations.
class AppSpace {
  AppSpace._();
  static const double s2 = 2, s4 = 4, s6 = 6, s8 = 8, s10 = 10, s12 = 12, s14 = 14;
  static const double s16 = 16, s20 = 20, s24 = 24, s28 = 28, s32 = 32;
  static const double s40 = 40, s48 = 48, s56 = 56, s64 = 64, s80 = 80;
}

class AppRadius {
  AppRadius._();
  static const Radius r8 = Radius.circular(8);
  static const Radius r12 = Radius.circular(12);
  static const Radius r14 = Radius.circular(14);
  static const Radius r16 = Radius.circular(16);
  static const Radius r20 = Radius.circular(20);
  static const Radius r24 = Radius.circular(24);
  static const Radius rFull = Radius.circular(999);

  static const BorderRadius b8 = BorderRadius.all(r8);
  static const BorderRadius b12 = BorderRadius.all(r12);
  static const BorderRadius b14 = BorderRadius.all(r14);
  static const BorderRadius b16 = BorderRadius.all(r16);
  static const BorderRadius b20 = BorderRadius.all(r20);
  static const BorderRadius b24 = BorderRadius.all(r24);
  static const BorderRadius bFull = BorderRadius.all(rFull);
}

class AppShadow {
  AppShadow._();
  static const List<BoxShadow> emphasize = [
    BoxShadow(color: Color(0x14000000), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0F000000), blurRadius: 4, offset: Offset(0, 1)),
  ];
  static const List<BoxShadow> strong = [
    BoxShadow(color: Color(0x1A171719), blurRadius: 8, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x12171719), blurRadius: 2, offset: Offset(0, 1)),
  ];
  static const List<BoxShadow> overlay = [
    BoxShadow(color: Color(0x1F000000), blurRadius: 40, offset: Offset(0, 12)),
    BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 4)),
  ];
}
