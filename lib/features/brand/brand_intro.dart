import 'dart:async';

import 'package:flutter/material.dart';

import 'brand_sfx.dart';
import 'brand_wordmark.dart';

/// First-login brand takeover — "IN by CLASS → HI CLASS 👋".
///
/// Timeline (controller is 2400ms):
///   0.0s  black stage, "IN by CLASS" fades up        — whoosh
///   0.5s  "by" slides right and fades away           — whoosh
///   1.0s  "HI" pops in (scale 0→1) between the words — pop
///   1.5s  "IN" collapses → reads "HI CLASS 👋"
///         subtitle fades up                          — soft bell
///   then a short hold, then [onDone].
class BrandIntro extends StatefulWidget {
  final VoidCallback? onDone;
  final Duration hold;
  const BrandIntro({super.key, this.onDone, this.hold = const Duration(milliseconds: 800)});

  /// Pushes the intro as a full-screen takeover and resolves when it finishes.
  static Future<void> show(BuildContext context) {
    final nav = Navigator.of(context, rootNavigator: true);
    return nav.push(PageRouteBuilder<void>(
      opaque: true,
      barrierColor: BrandPalette.canvas,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: const Duration(milliseconds: 360),
      pageBuilder: (ctx, _, __) => BrandIntro(onDone: () => Navigator.of(ctx).maybePop()),
      transitionsBuilder: (ctx, anim, sec, child) => FadeTransition(opacity: anim, child: child),
    ));
  }

  @override
  State<BrandIntro> createState() => _BrandIntroState();
}

class _BrandIntroState extends State<BrandIntro> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  Timer? _hold;
  final Set<int> _cues = {};

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))
      ..addListener(_onTick)
      ..addStatusListener(_onStatus);
    BrandSfx.play(BrandCue.whoosh); // logo entrance
    _c.forward();
  }

  void _onTick() {
    final t = _c.value;
    if (t >= 0.21 && _cues.add(1)) BrandSfx.play(BrandCue.whoosh); // by exit
    if (t >= 0.42 && _cues.add(2)) BrandSfx.play(BrandCue.pop); // HI pop
    if (t >= 0.67 && _cues.add(3)) BrandSfx.play(BrandCue.softBell); // tail
  }

  void _onStatus(AnimationStatus s) {
    if (s == AnimationStatus.completed) {
      _hold = Timer(widget.hold, () {
        if (mounted) widget.onDone?.call();
      });
    }
  }

  @override
  void dispose() {
    _hold?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = (MediaQuery.sizeOf(context).shortestSide * 0.14).clamp(40.0, 68.0);
    return Material(
      color: BrandPalette.canvas,
      child: SafeArea(
        child: Center(
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final t = _c.value;
              final fadeIn = brandSeg(t, 0.0, 0.21, Curves.easeOut);
              final byExit = brandSeg(t, 0.21, 0.42, Curves.easeInCubic);
              final hiPop = brandSeg(t, 0.42, 0.63, Curves.elasticOut);
              final collapse = brandSeg(t, 0.54, 0.71, Curves.easeInOutCubic);
              final tail = brandSeg(t, 0.67, 0.88, Curves.easeOut);
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Opacity(
                    opacity: fadeIn,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // "IN" — present at first, collapses away at the tail.
                        ClipRect(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            widthFactor: (1 - collapse).clamp(0.0, 1.0),
                            child: Opacity(
                              opacity: (1 - collapse).clamp(0.0, 1.0),
                              child: Padding(
                                padding: EdgeInsets.only(right: size * 0.16 * (1 - collapse)),
                                child: Text('IN', style: brandGlyph(size, BrandPalette.ink)),
                              ),
                            ),
                          ),
                        ),
                        // Center slot: "by" leaves while "HI" pops in.
                        _CenterSlot(byExit: byExit, hiPop: hiPop, size: size),
                        SizedBox(width: size * 0.16),
                        Text('CLASS', style: brandGlyph(size, BrandPalette.ink)),
                        // Wave joins once it reads "HI CLASS".
                        Opacity(
                          opacity: tail,
                          child: Padding(
                            padding: EdgeInsets.only(left: size * 0.18),
                            child: Text('👋', style: TextStyle(fontSize: size * 0.82)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: size * 0.5),
                  Opacity(
                    opacity: tail,
                    child: Transform.translate(
                      offset: Offset(0, 14 * (1 - tail)),
                      child: Text('오늘도 목표를 향해 한 걸음 더', style: brandSubtitle(size * 0.26)),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CenterSlot extends StatelessWidget {
  final double byExit;
  final double hiPop;
  final double size;
  const _CenterSlot({required this.byExit, required this.hiPop, required this.size});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // "by" slides right and fades.
        Opacity(
          opacity: (1 - byExit).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(size * 0.7 * byExit, 0),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: size * 0.16),
              child: Text('by', style: brandGlyph(size * 0.6, BrandPalette.muted, weight: FontWeight.w700)),
            ),
          ),
        ),
        // "HI" pops into the vacated slot.
        Opacity(
          opacity: hiPop.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: hiPop.clamp(0.0, 1.3),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: size * 0.14),
              child: Text('HI', style: brandGlyph(size, BrandPalette.accent)),
            ),
          ),
        ),
      ],
    );
  }
}
