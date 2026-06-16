import 'package:flutter/services.dart';

/// Named brand sound cues used across the motion pack.
enum BrandCue { whoosh, pop, softBell, ding, success }

/// Lightweight, dependency-free sound layer for the brand motion pack.
///
/// The pack ships no audio assets, so by default each cue maps to a
/// platform [SystemSound]/[HapticFeedback] combination — distinct enough to
/// feel intentional, and a no-op on platforms that don't support feedback.
/// To use real audio (e.g. whoosh.mp3, pop.wav), assign [handler] once at
/// startup and route cues to an audio engine; nothing else has to change.
class BrandSfx {
  BrandSfx._();

  /// Master switch — set `false` in tests/previews to silence feedback.
  static bool enabled = true;

  /// Optional sink. When set, it fully replaces the default feedback so a
  /// real audio backend can be plugged in without touching call sites.
  static void Function(BrandCue cue)? handler;

  static void play(BrandCue cue) {
    if (!enabled) return;
    final h = handler;
    if (h != null) {
      h(cue);
      return;
    }
    _playDefault(cue);
  }

  static void _playDefault(BrandCue cue) {
    switch (cue) {
      case BrandCue.whoosh:
        HapticFeedback.lightImpact();
      case BrandCue.pop:
        HapticFeedback.mediumImpact();
        SystemSound.play(SystemSoundType.click);
      case BrandCue.softBell:
        HapticFeedback.selectionClick();
      case BrandCue.ding:
        HapticFeedback.lightImpact();
        SystemSound.play(SystemSoundType.click);
      case BrandCue.success:
        HapticFeedback.heavyImpact();
        SystemSound.play(SystemSoundType.click);
    }
  }
}
