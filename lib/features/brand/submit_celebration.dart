import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'brand_sfx.dart';
import 'brand_wordmark.dart';

/// Worksheet-submit celebration — animated check, "✨ 제출 완료", and optional
/// reward chips. Themed to the app surface (not the black brand stage).
///
/// [tori] and [streakDays] are optional and each render a chip only when given,
/// so callers never show a reward that wasn't actually granted. Tapping the
/// scrim dismisses early.
class SubmitCelebration extends StatefulWidget {
  final String? subtitle;
  final int? tori;
  final int? streakDays;
  final VoidCallback? onDone;
  const SubmitCelebration({super.key, this.subtitle, this.tori, this.streakDays, this.onDone});

  static Future<void> show(
    BuildContext context, {
    String? subtitle,
    int? tori,
    int? streakDays,
  }) {
    final nav = Navigator.of(context, rootNavigator: true);
    return nav.push(PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (ctx, _, __) => SubmitCelebration(
        subtitle: subtitle,
        tori: tori,
        streakDays: streakDays,
        onDone: () => Navigator.of(ctx).maybePop(),
      ),
      transitionsBuilder: (ctx, anim, sec, child) => FadeTransition(opacity: anim, child: child),
    ));
  }

  @override
  State<SubmitCelebration> createState() => _SubmitCelebrationState();
}

class _SubmitCelebrationState extends State<SubmitCelebration> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  Timer? _hold;
  bool _done = false;
  bool _belled = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
      ..addListener(_onTick)
      ..addStatusListener(_onStatus);
    BrandSfx.play(BrandCue.pop); // the check landing
    _c.forward();
  }

  void _onTick() {
    if (!_belled && _c.value >= 0.45) {
      _belled = true;
      BrandSfx.play(BrandCue.success);
    }
  }

  void _onStatus(AnimationStatus s) {
    if (s == AnimationStatus.completed) {
      _hold = Timer(const Duration(milliseconds: 1300), _finish);
    }
  }

  void _finish() {
    if (_done) return;
    _done = true;
    widget.onDone?.call();
  }

  @override
  void dispose() {
    _hold?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return GestureDetector(
      onTap: _finish,
      behavior: HitTestBehavior.opaque,
      child: Material(
        type: MaterialType.transparency,
        child: Center(
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final t = _c.value;
              final cardIn = brandSeg(t, 0.0, 0.5, Curves.easeOutBack);
              final fade = brandSeg(t, 0.0, 0.25, Curves.easeOut);
              final checkP = brandSeg(t, 0.05, 0.6, Curves.easeOutCubic);
              final titleIn = brandSeg(t, 0.42, 0.72, Curves.easeOut);
              final toriIn = brandSeg(t, 0.6, 0.84, Curves.easeOutBack);
              final streakIn = brandSeg(t, 0.72, 0.96, Curves.easeOutBack);
              return Opacity(
                opacity: fade,
                child: Transform.scale(
                  scale: 0.9 + 0.1 * cardIn,
                  child: Container(
                    width: 300,
                    padding: const EdgeInsets.symmetric(vertical: AppSpace.s32, horizontal: AppSpace.s24),
                    decoration: BoxDecoration(
                      color: c.bgElevated,
                      borderRadius: AppRadius.b24,
                      boxShadow: AppShadow.overlay,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 88,
                          height: 88,
                          child: CustomPaint(
                            painter: _CheckPainter(progress: checkP, color: c.accent),
                          ),
                        ),
                        const SizedBox(height: AppSpace.s20),
                        Opacity(
                          opacity: titleIn,
                          child: Transform.translate(
                            offset: Offset(0, 10 * (1 - titleIn)),
                            child: Text('✨ 제출 완료',
                                style: AppType.title3.copyWith(color: c.labelStrong, fontWeight: FontWeight.w700)),
                          ),
                        ),
                        if (widget.subtitle != null) ...[
                          const SizedBox(height: AppSpace.s8),
                          Opacity(
                            opacity: titleIn,
                            child: Text(widget.subtitle!,
                                textAlign: TextAlign.center, style: AppType.body2.copyWith(color: c.labelAlt)),
                          ),
                        ],
                        if (widget.tori != null)
                          _chip(c, toriIn, c.accentSoft, c.accent, '+${widget.tori} 토리'),
                        if (widget.streakDays != null)
                          _chip(c, streakIn, c.cautionary.withValues(alpha: 0.14), c.cautionary,
                              '🔥 연속 학습 ${widget.streakDays}일'),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _chip(AppColors c, double anim, Color bg, Color fg, String text) {
    return Opacity(
      opacity: anim.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, 12 * (1 - anim)),
        child: Container(
          margin: const EdgeInsets.only(top: AppSpace.s8),
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16, vertical: AppSpace.s8),
          decoration: BoxDecoration(color: bg, borderRadius: AppRadius.bFull),
          child: Text(text, style: AppType.label1.copyWith(color: fg, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}

/// Draws a stroked ring (first ~60% of progress) then a check mark.
class _CheckPainter extends CustomPainter {
  final double progress;
  final Color color;
  _CheckPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 4;
    final ringP = (progress / 0.6).clamp(0.0, 1.0);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.08
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * ringP,
      false,
      ring,
    );

    final cp = ((progress - 0.5) / 0.5).clamp(0.0, 1.0);
    if (cp <= 0) return;
    final p1 = Offset(size.width * 0.30, size.height * 0.52);
    final p2 = Offset(size.width * 0.44, size.height * 0.66);
    final p3 = Offset(size.width * 0.72, size.height * 0.36);
    final check = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.09
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    final path = Path()..moveTo(p1.dx, p1.dy);
    if (cp <= 0.5) {
      final m = Offset.lerp(p1, p2, cp / 0.5)!;
      path.lineTo(m.dx, m.dy);
    } else {
      path.lineTo(p2.dx, p2.dy);
      final m = Offset.lerp(p2, p3, (cp - 0.5) / 0.5)!;
      path.lineTo(m.dx, m.dy);
    }
    canvas.drawPath(path, check);
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.progress != progress || old.color != color;
}
