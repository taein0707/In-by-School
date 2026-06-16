import 'package:flutter/material.dart';

import '../../core/theme/app_typography.dart';

/// Brand canvas palette for the full-screen takeover moments (intro / outro /
/// class enter). These run on a black stage regardless of app theme, so the
/// colors are fixed here. The accent stays the brand blue, brightened slightly
/// for legibility on black.
class BrandPalette {
  BrandPalette._();
  static const Color canvas = Color(0xFF000000);
  static const Color ink = Color(0xFFFFFFFF);
  static const Color muted = Color(0x73FFFFFF); // white @ 45%
  static const Color accent = Color(0xFF3385FF); // brand blue on dark
}

/// The brand wordmark glyph style — heavy Pretendard, tight tracking.
TextStyle brandGlyph(double size, Color color, {FontWeight weight = FontWeight.w800}) => TextStyle(
      fontFamily: AppType.family,
      fontSize: size,
      height: 1.0,
      fontWeight: weight,
      letterSpacing: -1.2,
      color: color,
    );

/// Supporting one-liner under the wordmark.
TextStyle brandSubtitle(double size) => TextStyle(
      fontFamily: AppType.family,
      fontSize: size,
      height: 1.4,
      fontWeight: FontWeight.w500,
      letterSpacing: -0.2,
      color: const Color(0xCCFFFFFF), // white @ 80%
    );

/// Eased interval sampler — maps a controller value `t` to 0→1 over [a,b].
double brandSeg(double t, double a, double b, Curve curve) {
  if (b <= a) return t >= b ? 1 : 0;
  final x = ((t - a) / (b - a)).clamp(0.0, 1.0);
  return curve.transform(x);
}

/// Shared whoosh-style transition for [AnimatedSwitcher] word swaps:
/// fade up from slightly below.
Widget brandSwitcherTransition(Widget child, Animation<double> anim) {
  final slide = Tween<Offset>(begin: const Offset(0, 0.22), end: Offset.zero)
      .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic));
  return FadeTransition(
    opacity: anim,
    child: SlideTransition(position: slide, child: child),
  );
}

/// One colored segment of a multi-color wordmark.
class BrandPart {
  final String text;
  final Color color;
  final double scale;
  final FontWeight weight;
  const BrandPart(this.text, this.color, {this.scale = 1, this.weight = FontWeight.w800});
}

/// A single-line wordmark made of one or more colored parts (e.g. blue "HI" +
/// white "CLASS"). Used for the discrete word frames in the takeovers.
class BrandWord extends StatelessWidget {
  final List<BrandPart> parts;
  final double size;
  const BrandWord(this.parts, {super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < parts.length; i++) {
      if (i > 0) children.add(SizedBox(width: size * 0.16));
      final p = parts[i];
      children.add(Text(p.text, style: brandGlyph(size * p.scale, p.color, weight: p.weight)));
    }
    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }
}
