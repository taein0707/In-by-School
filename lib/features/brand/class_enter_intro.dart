import 'dart:async';

import 'package:flutter/material.dart';

import 'brand_sfx.dart';
import 'brand_wordmark.dart';

/// Class-entry takeover — "IN → HI → <반 이름>", closing with an encouragement.
///
/// Used when a student opens a classroom. Sounds: whoosh per swap, soft bell as
/// the class name lands.
class ClassEnterIntro extends StatefulWidget {
  final String className;
  final VoidCallback? onDone;
  const ClassEnterIntro({super.key, required this.className, this.onDone});

  /// Pushes the takeover. No-op (returns immediately) when [className] is blank.
  static Future<void> show(BuildContext context, String? className) {
    final name = (className ?? '').trim();
    if (name.isEmpty) return Future<void>.value();
    final nav = Navigator.of(context, rootNavigator: true);
    return nav.push(PageRouteBuilder<void>(
      opaque: true,
      barrierColor: BrandPalette.canvas,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: const Duration(milliseconds: 360),
      pageBuilder: (ctx, _, __) => ClassEnterIntro(className: name, onDone: () => Navigator.of(ctx).maybePop()),
      transitionsBuilder: (ctx, anim, sec, child) => FadeTransition(opacity: anim, child: child),
    ));
  }

  @override
  State<ClassEnterIntro> createState() => _ClassEnterIntroState();
}

class _ClassEnterIntroState extends State<ClassEnterIntro> {
  int _stage = 0; // 0:IN  1:HI  2:class name (+ subtitle)
  final List<Timer> _timers = [];

  @override
  void initState() {
    super.initState();
    BrandSfx.play(BrandCue.whoosh);
    _at(650, () {
      setState(() => _stage = 1);
      BrandSfx.play(BrandCue.whoosh);
    });
    _at(1300, () {
      setState(() => _stage = 2);
      BrandSfx.play(BrandCue.softBell);
    });
    _at(3200, () => widget.onDone?.call());
  }

  void _at(int ms, VoidCallback f) {
    _timers.add(Timer(Duration(milliseconds: ms), () {
      if (mounted) f();
    }));
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = (MediaQuery.sizeOf(context).shortestSide * 0.14).clamp(40.0, 68.0);
    // Class names can be long ("영어 심화 1반"); shrink the name frame to fit.
    final nameSize = (base * 0.86).clamp(28.0, 56.0);
    return Material(
      color: BrandPalette.canvas,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 380),
                  transitionBuilder: brandSwitcherTransition,
                  child: KeyedSubtree(key: ValueKey(_stage), child: _frame(base, nameSize)),
                ),
                SizedBox(height: base * 0.5),
                AnimatedOpacity(
                  opacity: _stage >= 2 ? 1 : 0,
                  duration: const Duration(milliseconds: 380),
                  child: Text('오늘도 즐겁게 공부해보자!', style: brandSubtitle(base * 0.26)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _frame(double base, double nameSize) {
    switch (_stage) {
      case 0:
        return BrandWord(const [BrandPart('IN', BrandPalette.accent)], size: base);
      case 1:
        return BrandWord(const [BrandPart('HI', BrandPalette.accent)], size: base);
      default:
        return Text(
          widget.className,
          textAlign: TextAlign.center,
          style: brandGlyph(nameSize, BrandPalette.ink, weight: FontWeight.w700),
        );
    }
  }
}
