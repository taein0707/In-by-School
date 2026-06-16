import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_providers.dart';
import '../../app/settings_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/spirit/spirit_stage.dart';
import '../../shared/widgets/tori_spirit.dart';
import '../../shared/widgets/ui.dart';

/// Full-screen evolution event (진화는 특별한 순간).
///   • egg → 빛의 점 : interactive egg-cracking (user must crack it)
///   • any other stage-up : animated sequence 수축→빛 집중→소멸→등장→능력 해금
enum _Phase { eggCrack, burst, sequence, revealed }

class EvolutionPage extends ConsumerStatefulWidget {
  const EvolutionPage({super.key});
  @override
  ConsumerState<EvolutionPage> createState() => _EvolutionPageState();
}

class _EvolutionPageState extends ConsumerState<EvolutionPage> with TickerProviderStateMixin {
  static const int _maxTaps = 5;

  late final int _beforeStage;
  late final int _afterStage;
  late final bool _isEgg;
  late _Phase _phase;

  int _taps = 0;
  late final AnimationController _shake =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 280));
  late final AnimationController _burst =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
  late final AnimationController _seq =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2800));

  @override
  void initState() {
    super.initState();
    final r = ref.read(appProvider).lastResult;
    _beforeStage = r?.gain.beforeStage ?? 0;
    _afterStage = r?.gain.afterStage ?? 1;
    _isEgg = _beforeStage == 0;
    _phase = _isEgg ? _Phase.eggCrack : _Phase.sequence;

    _burst.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) setState(() => _phase = _Phase.revealed);
    });
    _seq.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) setState(() => _phase = _Phase.revealed);
    });
    if (!_isEgg) _seq.forward();
  }

  @override
  void dispose() {
    _shake.dispose();
    _burst.dispose();
    _seq.dispose();
    super.dispose();
  }

  void _onEggTap() {
    if (_phase != _Phase.eggCrack || _taps >= _maxTaps) return;
    _taps++;
    _shake.forward(from: 0);
    switch (_taps) {
      case 1:
        HapticFeedback.selectionClick();
        break;
      case 2:
        HapticFeedback.lightImpact();
        break;
      case 3:
        HapticFeedback.mediumImpact();
        break;
      case 4:
        HapticFeedback.heavyImpact();
        break;
      case 5:
        HapticFeedback.heavyImpact();
        HapticFeedback.vibrate();
        setState(() => _phase = _Phase.burst);
        _burst.forward();
        return;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: switch (_phase) {
          _Phase.revealed => _reveal(context),
          _Phase.sequence => _sequence(context),
          _ => _egg(context),
        },
      ),
    );
  }

  // ---------- egg-crack (interactive) ----------
  Widget _egg(BuildContext context) {
    final c = context.c;
    final accent = ref.watch(settingsProvider).accent;
    final progress = _taps / _maxTaps;
    return Column(
      children: [
        const Spacer(),
        Text('알이 깨어나려 해요', style: AppType.title3),
        const SizedBox(height: AppSpace.s8),
        Text('토리를 톡톡 두드려 깨워주세요', style: AppType.body1.copyWith(color: c.labelAlt)),
        const Spacer(),
        GestureDetector(
          onTap: _onEggTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedBuilder(
            animation: Listenable.merge([_shake, _burst]),
            builder: (context, _) {
              final amp = (6 + _taps * 2) * (1 - _shake.value);
              final dx = math.sin(_shake.value * math.pi * 7) * amp;
              final burstT = _burst.value;
              return Transform.translate(
                offset: Offset(dx, 0),
                child: SizedBox(
                  width: 240,
                  height: 240,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Opacity(
                        opacity: 1 - burstT,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            ToriSpirit(stageIndex: 0, size: 200, accent: accent, animate: false),
                            CustomPaint(size: const Size(200, 200), painter: _CrackPainter(progress)),
                          ],
                        ),
                      ),
                      if (burstT > 0)
                        CustomPaint(size: const Size(240, 240), painter: _BurstPainter(burstT, accent)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const Spacer(),
        // tap progress dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_maxTaps, (i) {
            final on = i < _taps;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: on ? accent : c.fillStrong,
              ),
            );
          }),
        ),
        const Spacer(),
      ],
    );
  }

  // ---------- evolution sequence (animated) ----------
  Widget _sequence(BuildContext context) {
    final accent = ref.watch(settingsProvider).accent;
    return Center(
      child: AnimatedBuilder(
        animation: _seq,
        builder: (context, _) {
          final t = _seq.value;
          // phases
          final shrink = Curves.easeIn.transform((t / 0.24).clamp(0.0, 1.0));
          final oldOpacity = 1 - ((t - 0.12) / 0.18).clamp(0.0, 1.0);
          final flash = t < 0.5 ? ((t - 0.18) / 0.22).clamp(0.0, 1.0) : (1 - ((t - 0.5) / 0.18)).clamp(0.0, 1.0);
          final newIn = ((t - 0.5) / 0.32).clamp(0.0, 1.0);
          final newScale = 0.4 + Curves.elasticOut.transform(newIn) * 0.6;
          return SizedBox(
            width: 260,
            height: 260,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (oldOpacity > 0)
                  Opacity(
                    opacity: oldOpacity.toDouble(),
                    child: Transform.scale(
                      scale: 1 - shrink * 0.5,
                      child: ToriSpirit(stageIndex: _beforeStage, size: 180, accent: accent, animate: false),
                    ),
                  ),
                if (flash > 0)
                  Container(
                    width: 80 + flash * 180,
                    height: 80 + flash * 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [
                        Colors.white.withValues(alpha: flash.toDouble()),
                        accent.withValues(alpha: (flash * 0.4).toDouble()),
                        Colors.transparent,
                      ]),
                    ),
                  ),
                if (newIn > 0)
                  Opacity(
                    opacity: newIn.toDouble(),
                    child: Transform.scale(
                      scale: newScale,
                      child: ToriSpirit(stageIndex: _afterStage, size: 180, accent: accent, animate: false),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---------- reveal + AI ability unlock ----------
  Widget _reveal(BuildContext context) {
    final c = context.c;
    final accent = ref.watch(settingsProvider).accent;
    final stage = SpiritStage.all[_afterStage];
    final g = ref.watch(appProvider).growth;
    return Padding(
      padding: const EdgeInsets.all(AppSpace.s24),
      child: Column(
        children: [
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: c.accentSoft, borderRadius: AppRadius.bFull),
            child: Text(_isEgg ? '부화!' : '✦ 진화 ✦',
                style: AppType.headline2.copyWith(color: c.accent, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: AppSpace.s16),
          ToriSpirit(stageIndex: _afterStage, size: 170, accent: accent, levelUp: true),
          const SizedBox(height: AppSpace.s8),
          Text('${stage.name} · LV ${g.level}', style: AppType.headline2.copyWith(color: c.labelNeutral)),
          const SizedBox(height: AppSpace.s20),
          OclCard(
            color: c.accentSoft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('토리가 새로 배웠어요', style: AppType.label2.copyWith(color: c.accent, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(stage.learned, style: AppType.body1.copyWith(color: c.labelNeutral, fontWeight: FontWeight.w500)),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpace.s12),
                  child: Divider(height: 1, color: c.line),
                ),
                Text('이제 이렇게 말할 수 있어요', style: AppType.label2.copyWith(color: c.labelAlt)),
                const SizedBox(height: 4),
                Text('“${stage.sampleLine}”', style: AppType.body1.copyWith(color: c.labelNormal)),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.s12),
          Text('정령이 자랐다는 건, 토리의 분석이 그만큼 깊어졌다는 뜻이에요.',
              textAlign: TextAlign.center, style: AppType.caption1.copyWith(color: c.labelAlt)),
          const Spacer(),
          OclButton('확인', onPressed: () => context.go('/home')),
        ],
      ),
    );
  }
}

/// Cracks spreading across the shell as the user taps.
class _CrackPainter extends CustomPainter {
  final double progress; // 0..1
  _CrackPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final cx = size.width / 2, cy = size.height * 0.52;
    final maxLen = size.height * 0.34;
    final paint = Paint()
      ..color = const Color(0xFF1B1C1E).withValues(alpha: (0.55 * progress).clamp(0.0, 0.55))
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    // a few jagged cracks radiating from a center seam
    const seeds = [-1.4, -0.5, 0.4, 1.2, 2.4];
    final n = (progress * seeds.length).ceil();
    for (int i = 0; i < n; i++) {
      final a = seeds[i];
      final len = maxLen * progress;
      final path = Path()..moveTo(cx, cy);
      var x = cx, y = cy;
      const steps = 4;
      for (int s = 1; s <= steps; s++) {
        final f = s / steps;
        final jitter = (s.isEven ? 1 : -1) * 6.0 * f;
        x = cx + math.cos(a) * len * f + math.sin(a) * jitter;
        y = cy + math.sin(a) * len * f - math.cos(a) * jitter;
        path.lineTo(x, y);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_CrackPainter old) => old.progress != progress;
}

/// Light burst + shell shards flying outward on the final crack.
class _BurstPainter extends CustomPainter {
  final double t; // 0..1
  final Color accent;
  _BurstPainter(this.t, this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    // flash
    final flashR = size.width * (0.1 + t * 0.5);
    canvas.drawCircle(
      Offset(cx, cy),
      flashR,
      Paint()
        ..shader = RadialGradient(colors: [
          Colors.white.withValues(alpha: (1 - t).clamp(0.0, 1.0)),
          accent.withValues(alpha: ((1 - t) * 0.5).clamp(0.0, 1.0)),
          Colors.transparent,
        ]).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: flashR)),
    );
    // shards
    final shard = Paint()..color = Color.alphaBlend(accent.withValues(alpha: 0.4), Colors.white).withValues(alpha: (1 - t).clamp(0.0, 1.0));
    const count = 12;
    final dist = size.width * 0.5 * Curves.easeOut.transform(t);
    for (int i = 0; i < count; i++) {
      final a = (i / count) * 2 * math.pi;
      final x = cx + math.cos(a) * dist;
      final y = cy + math.sin(a) * dist;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(a + t * 3);
      final s = 9.0 * (1 - t);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: s, height: s * 1.6), const Radius.circular(2)),
        shard,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t;
}
