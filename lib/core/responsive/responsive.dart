import 'package:flutter/widgets.dart';

/// P5 반응형 — 화면 폭에 따른 3단 레이아웃 구분.
/// Mobile(<700): 기존 하단 탭 / Tablet(>=700): NavigationRail / Desktop(>=1000): Sidebar.
enum ScreenSize { mobile, tablet, desktop }

class Breakpoints {
  Breakpoints._();

  /// >= 이 폭이면 태블릿(레일) 레이아웃.
  static const double tablet = 700;

  /// >= 이 폭이면 데스크톱(사이드바+푸터) 레이아웃.
  static const double desktop = 1000;
}

/// 폭(logical px) → 화면 구분.
ScreenSize screenSizeOf(double width) {
  if (width >= Breakpoints.desktop) return ScreenSize.desktop;
  if (width >= Breakpoints.tablet) return ScreenSize.tablet;
  return ScreenSize.mobile;
}

/// `context.screenSize`, `context.isDesktop` 등 간편 접근.
extension ResponsiveX on BuildContext {
  ScreenSize get screenSize => screenSizeOf(MediaQuery.sizeOf(this).width);
  bool get isMobile => screenSize == ScreenSize.mobile;
  bool get isTablet => screenSize == ScreenSize.tablet;
  bool get isDesktop => screenSize == ScreenSize.desktop;

  /// 데스크톱 콘텐츠 최대 폭(가독성 — 너무 넓게 늘어지지 않게).
  bool get isWide => screenSize != ScreenSize.mobile;
}
