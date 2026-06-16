import 'dart:async';

import 'package:flutter/material.dart';

import 'brand_sfx.dart';
import 'brand_wordmark.dart';

/// Logout brand takeover — "HI CLASS → HI → OUT → OUT by CLASS".
///
/// Discrete word frames swapped with the shared whoosh transition, closing on
/// "See you tomorrow 👋". Sounds: whoosh per swap, ding on the final lockup.
class BrandOutro extends StatefulWidget {
  final VoidCallback? onDone;
  const BrandOutro({super.key, this.onDone});

  static Future<void> show(BuildContext context) {
    final nav = Navigator.of(context, rootNavigator: true);
    return nav.push(PageRouteBuilder<void>(
      opaque: true,
      barrierColor: BrandPalette.canvas,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: const Duration(milliseconds: 360),
      pageBuilder: (ctx, _, __) => BrandOutro(onDone: () => Navigator.of(ctx).maybePop()),
      transitionsBuilder: (ctx, anim, sec, child) => FadeTransition(opacity: anim, child: child),
    ));
  }

  @override
  State<BrandOutro> createState() => _BrandOutroState();
}

class _BrandOutroState extends State<BrandOutro> {
  int _stage = 0; // 0:HI CLASS  1:HI  2:OUT  3:OUT by CLASS
  final List<Timer> _timers = [];

  @override
  void initState() {
    super.initState();
    BrandSfx.play(BrandCue.whoosh);
    _at(700, () {
      setState(() => _stage = 1);
      BrandSfx.play(BrandCue.whoosh);
    });
    _at(1300, () {
      setState(() => _stage = 2);
      BrandSfx.play(BrandCue.whoosh);
    });
    _at(1950, () {
      setState(() => _stage = 3);
      BrandSfx.play(BrandCue.ding);
    });
    _at(3500, () => widget.onDone?.call());
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
    final size = (MediaQuery.sizeOf(context).shortestSide * 0.14).clamp(40.0, 68.0);
    return Material(
      color: BrandPalette.canvas,
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 380),
                transitionBuilder: brandSwitcherTransition,
                child: KeyedSubtree(key: ValueKey(_stage), child: _frame(size)),
              ),
              SizedBox(height: size * 0.5),
              AnimatedOpacity(
                opacity: _stage >= 3 ? 1 : 0,
                duration: const Duration(milliseconds: 360),
                child: Text('See you tomorrow 👋', style: brandSubtitle(size * 0.26)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _frame(double size) {
    switch (_stage) {
      case 0:
        return BrandWord(const [
          BrandPart('HI', BrandPalette.accent),
          BrandPart('CLASS', BrandPalette.ink),
        ], size: size);
      case 1:
        return BrandWord(const [BrandPart('HI', BrandPalette.accent)], size: size);
      case 2:
        return BrandWord(const [BrandPart('OUT', BrandPalette.ink)], size: size);
      default:
        return BrandWord(const [
          BrandPart('OUT', BrandPalette.ink),
          BrandPart('by', BrandPalette.muted, scale: 0.6, weight: FontWeight.w700),
          BrandPart('CLASS', BrandPalette.ink),
        ], size: size);
    }
  }
}
