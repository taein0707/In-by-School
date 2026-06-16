import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 토리 — a single knowledge spirit rendered as a parametric vector character.
///
/// The same being across all 10 stages: its **silhouette** changes (hood,
/// crown, pauldrons, staff, halo, flowing hem) so it reads as a different
/// form from afar — NOT just a bigger aura. Identity (eyes + warm light core)
/// stays constant so it's always recognizably 토리.
class ToriSpirit extends StatefulWidget {
  final int stageIndex; // 0..9
  final double size;
  final Color accent;
  final bool sleeping;
  final bool animate;
  final bool levelUp; // play a one-shot spring pop on appear

  const ToriSpirit({
    super.key,
    required this.stageIndex,
    this.size = 180,
    this.accent = const Color(0xFF0066FF),
    this.sleeping = false,
    this.animate = true,
    this.levelUp = false,
  });

  @override
  State<ToriSpirit> createState() => _ToriSpiritState();
}

class _ToriSpiritState extends State<ToriSpirit> with TickerProviderStateMixin {
  // Multi-channel idle: breathing (scale) + float (translateY) + micro-tilt
  // (rotate) + periodic blink. Never lazily created during dispose.
  AnimationController? _idle;
  AnimationController? _pop; // one-shot level-up spring
  late final Animation<double> _popScale;

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _idle = AnimationController(vsync: this, duration: const Duration(milliseconds: 3600))..repeat();
    }
    if (widget.levelUp) {
      _pop = AnimationController(vsync: this, duration: const Duration(milliseconds: 540));
      _popScale = TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.15).chain(CurveTween(curve: Curves.easeOut)), weight: 42),
        TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)), weight: 58),
      ]).animate(_pop!);
      _pop!.forward();
    }
  }

  @override
  void dispose() {
    _idle?.dispose();
    _pop?.dispose();
    super.dispose();
  }

  Widget _paintWith(double eyeOpen) => SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(
          painter: _ToriPainter(
            stageIndex: widget.stageIndex.clamp(0, 9),
            accent: widget.accent,
            sleeping: widget.sleeping,
            eyeOpen: eyeOpen,
          ),
        ),
      );

  Widget _withPop(Widget child) {
    final pop = _pop;
    if (pop == null) return child;
    return AnimatedBuilder(
      animation: _popScale,
      builder: (_, c) => Transform.scale(scale: _popScale.value, child: c),
      child: child,
    );
  }

  // one quick blink near the start of each idle cycle (~every 3.6s)
  double _eyeOpen(double t) {
    const dur = 0.045;
    if (t < dur) return (math.cos((t / dur) * 2 * math.pi) + 1) / 2;
    return 1.0;
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final idle = _idle;
    if (reduce || idle == null) return _withPop(_paintWith(1.0));
    return AnimatedBuilder(
      animation: idle,
      builder: (context, _) {
        final t = idle.value;
        const tau = 2 * math.pi;
        final breathe = 1 + 0.02 * math.sin(t * tau);
        final float = math.sin(t * tau) * 3.0;
        final tilt = math.sin(t * tau * 0.5) * 0.02;
        return _withPop(
          Transform.translate(
            offset: Offset(0, -float),
            child: Transform.rotate(
              angle: tilt,
              child: Transform.scale(scale: breathe, child: _paintWith(_eyeOpen(t))),
            ),
          ),
        );
      },
    );
  }
}

/// Per-stage silhouette configuration. Each stage changes the SHAPE
/// (wings, hood, crown, pauldrons, staff, halo, tails) and at key stages the
/// COLOR (teal/gold) — so it reads as a different being from afar.
class _Form {
  final bool egg;
  final double bodyH; // body height fraction of canvas
  final double bodyW; // body width fraction of canvas
  final int tails; // flowing-hem humps
  final int wings; // 0 none · 1 buds · 2 single · 3 double · 4 grand
  final int tint; // 0 accent · 1 teal(청록) · 2 gold(황금)
  final bool mouth, arms, foreheadMark, hood, crown, pauldrons, staff, halo, essence, glyphSkin;
  final double warmth; // subtle, constant-ish glow

  const _Form({
    this.egg = false,
    this.bodyH = 0.6,
    this.bodyW = 0.55,
    this.tails = 1,
    this.wings = 0,
    this.tint = 0,
    this.mouth = false,
    this.arms = false,
    this.foreheadMark = false,
    this.hood = false,
    this.crown = false,
    this.pauldrons = false,
    this.staff = false,
    this.halo = false,
    this.essence = false,
    this.glyphSkin = false,
    this.warmth = 0.4,
  });

  static const List<_Form> all = [
    _Form(egg: true, warmth: 0.30), // 0 알
    _Form(bodyH: 0.40, bodyW: 0.40, tails: 1, warmth: 0.45), // 1 빛의 점
    _Form(bodyH: 0.56, bodyW: 0.54, tails: 1, wings: 1, mouth: true, warmth: 0.55), // 2 작은: 날개 싹
    _Form(bodyH: 0.66, bodyW: 0.58, tails: 2, wings: 2, mouth: true, arms: true, foreheadMark: true, warmth: 0.65), // 3 정령: 팔·날개
    _Form(bodyH: 0.70, bodyW: 0.60, tails: 2, wings: 3, tint: 1, mouth: true, arms: true, foreheadMark: true, hood: true, warmth: 0.72), // 4 고급: 이중 날개·청록
    _Form(bodyH: 0.74, bodyW: 0.58, tails: 3, wings: 3, tint: 1, mouth: true, arms: true, foreheadMark: true, crown: true, essence: true, warmth: 0.80), // 5 현명: 빛의 관·지식 정수
    _Form(bodyH: 0.76, bodyW: 0.70, tails: 3, wings: 3, mouth: true, arms: true, foreheadMark: true, pauldrons: true, halo: true, warmth: 0.86), // 6 수호: 어깨 갑주·오라
    _Form(bodyH: 0.80, bodyW: 0.70, tails: 4, wings: 4, mouth: true, arms: true, foreheadMark: true, hood: true, essence: true, warmth: 0.92), // 7 대정령: 다중 꼬리·큰 날개
    _Form(bodyH: 0.83, bodyW: 0.66, tails: 4, wings: 4, tint: 2, mouth: true, arms: true, foreheadMark: true, crown: true, staff: true, warmth: 0.96), // 8 현자: 황금·지팡이
    _Form(bodyH: 0.86, bodyW: 0.70, tails: 5, wings: 4, tint: 2, mouth: true, arms: true, foreheadMark: true, crown: true, staff: true, halo: true, essence: true, glyphSkin: true, warmth: 1.0), // 9 아카이브: 황금·글리프 피부
  ];
}

class _ToriPainter extends CustomPainter {
  final int stageIndex;
  final Color accent;
  final bool sleeping;
  final double eyeOpen; // 0 = closed (blink), 1 = open

  _ToriPainter({required this.stageIndex, required this.accent, required this.sleeping, this.eyeOpen = 1.0});

  static const Color _ink = Color(0xFF1B1C1E);
  static const Color _white = Color(0xFFFFFFFF);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final cx = s / 2;
    final f = _Form.all[stageIndex];

    // per-stage hue: teal at 4–5, gold at 8–9 (blended with the base accent)
    final tintC = f.tint == 1
        ? const Color(0xFF12B5A3)
        : f.tint == 2
            ? const Color(0xFFF6B23C)
            : accent;
    final spirit = f.tint == 0 ? accent : Color.lerp(accent, tintC, 0.65)!;

    // --- soft glow (subtle, NOT the growth mechanism) ---
    final glow = Paint()
      ..color = spirit.withValues(alpha: 0.18 + f.warmth * 0.10)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.07);
    canvas.drawCircle(Offset(cx, s * 0.5), s * 0.34, glow);

    if (f.egg) {
      _paintEgg(canvas, s, cx);
      return;
    }

    final bodyW = s * f.bodyW;
    final bodyH = s * f.bodyH;
    final bottomY = s * 0.90;
    final topY = bottomY - bodyH;
    final r = bodyW / 2;
    final left = cx - r;
    final right = cx + r;
    final headCy = topY + r;

    if (f.halo) _paintHalo(canvas, cx, headCy, r, spirit);
    if (f.staff) _paintStaff(canvas, right, headCy, bottomY, spirit);
    if (f.wings > 0) _paintWings(canvas, cx, headCy + r * 0.45, r, f.wings, spirit);

    // --- body silhouette ---
    final body = _bodyPath(left, right, cx, headCy, r, bottomY, f.tails);
    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_white, Color.alphaBlend(spirit.withValues(alpha: 0.30), _white), spirit],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(left, topY, bodyW, bodyH));
    canvas.drawPath(body, bodyPaint);
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Color.alphaBlend(spirit.withValues(alpha: 0.5), _white),
    );

    if (f.glyphSkin) _paintGlyphSkin(canvas, cx, headCy, r);
    if (f.hood) _paintHood(canvas, cx, topY, r, spirit);
    if (f.pauldrons) _paintPauldrons(canvas, left, right, headCy + r * 0.6, r, spirit);
    if (f.arms) _paintArms(canvas, left, right, headCy + r * 0.5, r, spirit);
    if (f.crown) _paintCrown(canvas, cx, topY, r, spirit);
    if (f.foreheadMark) _paintMark(canvas, cx, headCy - r * 0.5, r, spirit);
    if (f.essence) _paintEssence(canvas, cx, headCy, r, spirit);

    _paintFace(canvas, cx, headCy, r, f.mouth);
  }

  Path _bodyPath(double left, double right, double cx, double headCy, double r, double bottomY, int tails) {
    final p = Path();
    final baseY = bottomY - r * 0.18;
    p.moveTo(left, baseY);
    p.lineTo(left, headCy);
    // head: semicircle over the top
    p.arcToPoint(Offset(right, headCy), radius: Radius.circular(r), clockwise: true);
    p.lineTo(right, baseY);
    // flowing hem: `tails` humps from right back to left
    final span = (right - left) / tails;
    for (int i = 0; i < tails; i++) {
      final x0 = right - span * i;
      final x1 = right - span * (i + 1);
      final midX = (x0 + x1) / 2;
      p.quadraticBezierTo(midX, bottomY + r * 0.10, x1, baseY);
    }
    p.close();
    return p;
  }

  void _paintEgg(Canvas canvas, double s, double cx) {
    final cy = s * 0.52;
    final rx = s * 0.23, ry = s * 0.29;
    final rect = Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2);
    canvas.drawOval(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_white, Color.alphaBlend(accent.withValues(alpha: 0.28), _white), accent],
        ).createShader(rect),
    );
    canvas.drawOval(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Color.alphaBlend(accent.withValues(alpha: 0.45), _white),
    );
    // faint seams
    final seam = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = Color.alphaBlend(accent.withValues(alpha: 0.5), _white);
    final p1 = Path()
      ..moveTo(cx - rx * 0.6, cy - ry * 0.1)
      ..quadraticBezierTo(cx, cy - ry * 0.3, cx + rx * 0.6, cy - ry * 0.05);
    final p2 = Path()
      ..moveTo(cx - rx * 0.55, cy + ry * 0.25)
      ..quadraticBezierTo(cx, cy + ry * 0.45, cx + rx * 0.55, cy + ry * 0.2);
    canvas.drawPath(p1, seam);
    canvas.drawPath(p2, seam);
    // inner spark
    canvas.drawCircle(Offset(cx, cy), s * 0.05, Paint()..color = _white.withValues(alpha: 0.85));
  }

  void _paintFace(Canvas canvas, double cx, double headCy, double r, bool mouth) {
    final eyeDx = r * 0.42;
    final eyeY = headCy + r * 0.02;
    final open = sleeping ? 0.0 : eyeOpen;
    if (open < 0.16) {
      // closed / blinking → short curved lashes
      final p = Paint()
        ..color = _ink
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      for (final dx in [-eyeDx, eyeDx]) {
        canvas.drawArc(
          Rect.fromCenter(center: Offset(cx + dx, eyeY), width: r * 0.22, height: r * 0.16),
          0.15, math.pi - 0.3, false, p,
        );
      }
      return;
    }
    final eye = Paint()..color = _ink;
    final eh = r * 0.28 * open;
    canvas.drawOval(Rect.fromCenter(center: Offset(cx - eyeDx, eyeY), width: r * 0.20, height: eh), eye);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx + eyeDx, eyeY), width: r * 0.20, height: eh), eye);
    // blush
    final blush = Paint()..color = accent.withValues(alpha: 0.18);
    canvas.drawCircle(Offset(cx - eyeDx - r * 0.18, eyeY + r * 0.22), r * 0.12, blush);
    canvas.drawCircle(Offset(cx + eyeDx + r * 0.18, eyeY + r * 0.22), r * 0.12, blush);
    if (mouth) {
      final m = Path()
        ..moveTo(cx - r * 0.12, eyeY + r * 0.30)
        ..quadraticBezierTo(cx, eyeY + r * 0.46, cx + r * 0.12, eyeY + r * 0.30);
      canvas.drawPath(
        m,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round
          ..color = _ink,
      );
    }
  }

  void _paintHood(Canvas canvas, double cx, double topY, double r, Color a) {
    // a pointed hood/cloak sitting over the head, widening the silhouette
    final p = Path()
      ..moveTo(cx - r * 1.15, topY + r * 1.15)
      ..quadraticBezierTo(cx - r * 0.2, topY - r * 0.55, cx, topY - r * 0.35)
      ..quadraticBezierTo(cx + r * 0.2, topY - r * 0.55, cx + r * 1.15, topY + r * 1.15)
      ..quadraticBezierTo(cx, topY + r * 0.65, cx - r * 1.15, topY + r * 1.15)
      ..close();
    canvas.drawPath(p, Paint()..color = Color.alphaBlend(a.withValues(alpha: 0.55), _white));
    canvas.drawPath(
      p,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Color.alphaBlend(a.withValues(alpha: 0.7), _white),
    );
  }

  void _paintCrown(Canvas canvas, double cx, double topY, double r, Color a) {
    final paint = Paint()..color = a.withValues(alpha: 0.9);
    final w = r * 0.9;
    final baseY = topY + r * 0.05;
    final p = Path()..moveTo(cx - w, baseY);
    const points = 3;
    for (int i = 0; i < points; i++) {
      final x0 = cx - w + (2 * w / points) * i;
      final x1 = cx - w + (2 * w / points) * (i + 1);
      p.lineTo((x0 + x1) / 2, baseY - r * 0.42);
      p.lineTo(x1, baseY);
    }
    p.close();
    canvas.drawPath(p, paint);
  }

  void _paintPauldrons(Canvas canvas, double left, double right, double y, double r, Color a) {
    final paint = Paint()..color = Color.alphaBlend(a.withValues(alpha: 0.5), _white);
    canvas.drawCircle(Offset(left + r * 0.05, y), r * 0.34, paint);
    canvas.drawCircle(Offset(right - r * 0.05, y), r * 0.34, paint);
  }

  void _paintArms(Canvas canvas, double left, double right, double y, double r, Color accent) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.16
      ..strokeCap = StrokeCap.round
      ..color = Color.alphaBlend(accent.withValues(alpha: 0.35), _white);
    canvas.drawPath(
      Path()
        ..moveTo(left + r * 0.15, y)
        ..quadraticBezierTo(left - r * 0.15, y + r * 0.35, left + r * 0.1, y + r * 0.6),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(right - r * 0.15, y)
        ..quadraticBezierTo(right + r * 0.15, y + r * 0.35, right - r * 0.1, y + r * 0.6),
      paint,
    );
  }

  void _paintStaff(Canvas canvas, double right, double headCy, double bottomY, Color a) {
    final x = right + (bottomY - headCy) * 0.14 + 8;
    final paint = Paint()
      ..color = Color.alphaBlend(a.withValues(alpha: 0.5), _white)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(x, headCy - 6), Offset(x, bottomY), paint);
    canvas.drawCircle(Offset(x, headCy - 12), 7, Paint()..color = a);
    canvas.drawCircle(Offset(x, headCy - 12), 7, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = _white.withValues(alpha: 0.6));
  }

  void _paintHalo(Canvas canvas, double cx, double headCy, double r, Color a) {
    canvas.drawCircle(
      Offset(cx, headCy),
      r * 1.35,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = a.withValues(alpha: 0.45),
    );
  }

  void _paintMark(Canvas canvas, double cx, double y, double r, Color a) {
    // a small knowledge glyph (diamond) on the forehead — part of the body
    final p = Path()
      ..moveTo(cx, y - r * 0.16)
      ..lineTo(cx + r * 0.13, y)
      ..lineTo(cx, y + r * 0.16)
      ..lineTo(cx - r * 0.13, y)
      ..close();
    canvas.drawPath(p, Paint()..color = a.withValues(alpha: 0.85));
  }

  // wings — the biggest silhouette differentiator across stages
  void _paintWings(Canvas canvas, double cx, double shoulderY, double r, int level, Color a) {
    if (level == 1) {
      // 날개 싹 (buds)
      final bud = Paint()..color = Color.alphaBlend(a.withValues(alpha: 0.5), _white);
      for (final sgn in [-1.0, 1.0]) {
        canvas.drawOval(
          Rect.fromCenter(center: Offset(cx + sgn * r * 0.95, shoulderY - r * 0.1), width: r * 0.5, height: r * 0.36),
          bud,
        );
      }
      return;
    }
    final layers = (level - 1).clamp(1, 3); // 2→1, 3→2, 4→3
    for (final sgn in [-1.0, 1.0]) {
      for (int i = 0; i < layers; i++) {
        final spread = r * (0.95 + i * 0.5);
        final lift = r * (0.5 + i * 0.35);
        final path = Path()
          ..moveTo(cx + sgn * r * 0.35, shoulderY)
          ..quadraticBezierTo(cx + sgn * spread, shoulderY - lift * 1.7, cx + sgn * spread * 1.02, shoulderY - lift * 0.1)
          ..quadraticBezierTo(cx + sgn * spread * 0.8, shoulderY + lift * 0.55, cx + sgn * r * 0.35, shoulderY + r * 0.25)
          ..close();
        canvas.drawPath(path, Paint()..color = Color.alphaBlend(a.withValues(alpha: (0.5 - i * 0.12).clamp(0.15, 0.5)), _white));
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = a.withValues(alpha: 0.5),
        );
      }
    }
  }

  // 지식 정수 — a small glowing diamond floating beside the head
  void _paintEssence(Canvas canvas, double cx, double headCy, double r, Color a) {
    final ex = cx + r * 1.15, ey = headCy - r * 0.95;
    canvas.drawCircle(
      Offset(ex, ey),
      r * 0.2,
      Paint()
        ..color = a.withValues(alpha: 0.3)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.16),
    );
    final d = r * 0.17;
    final p = Path()
      ..moveTo(ex, ey - d)
      ..lineTo(ex + d * 0.7, ey)
      ..lineTo(ex, ey + d)
      ..lineTo(ex - d * 0.7, ey)
      ..close();
    canvas.drawPath(p, Paint()..color = a);
    canvas.drawPath(p, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = _white.withValues(alpha: 0.8));
  }

  // 글리프 피부 — knowledge marks woven into the body (archive stage)
  void _paintGlyphSkin(Canvas canvas, double cx, double headCy, double r) {
    const glyphs = ['∑', 'π', '∫', 'x', '√'];
    final spots = [
      Offset(cx - r * 0.32, headCy + r * 0.55),
      Offset(cx + r * 0.36, headCy + r * 0.75),
      Offset(cx, headCy + r * 1.05),
      Offset(cx - r * 0.05, headCy + r * 0.25),
      Offset(cx + r * 0.1, headCy + r * 1.35),
    ];
    for (int i = 0; i < spots.length; i++) {
      final tp = TextPainter(
        text: TextSpan(
          text: glyphs[i % glyphs.length],
          style: TextStyle(fontSize: r * 0.22, color: _white.withValues(alpha: 0.55), fontWeight: FontWeight.w700),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, spots[i] - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_ToriPainter old) =>
      old.stageIndex != stageIndex ||
      old.accent != accent ||
      old.sleeping != sleeping ||
      old.eyeOpen != eyeOpen;
}
