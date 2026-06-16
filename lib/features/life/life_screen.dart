import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_providers.dart';
import '../../app/settings_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/life/life.dart';
import '../../domain/spirit/spirit_stage.dart';
import '../../shared/widgets/tori_spirit.dart';
import '../../shared/widgets/ui.dart';

/// 사망 → 골든타임(부활) → 관(새 정령/기억 계승).
class LifeScreen extends ConsumerStatefulWidget {
  const LifeScreen({super.key});
  @override
  ConsumerState<LifeScreen> createState() => _LifeScreenState();
}

class _LifeScreenState extends ConsumerState<LifeScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(appProvider.notifier).tickLife());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      ref.read(appProvider.notifier).tickLife();
      setState(() {}); // refresh countdown
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final app = ref.watch(appProvider);
    final life = app.life;
    final accent = ref.watch(settingsProvider).accent;

    Widget body;
    if (life.state == LifeState.coffin || (life.state == LifeState.dead && app.coffin != null)) {
      body = _coffin(context, c, accent, app);
    } else if (life.state == LifeState.dead) {
      body = _dead(context, c, accent, life);
    } else {
      body = _safe(context, c, accent, app);
    }

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => context.go('/home')),
      ),
      body: SafeArea(child: Padding(padding: const EdgeInsets.all(AppSpace.s24), child: body)),
    );
  }

  // ---- dead, within golden time ----
  Widget _dead(BuildContext context, AppColors c, Color accent, Life life) {
    final rem = life.goldenRemaining(DateTime.now());
    final canRevive = life.antidotes > 0;
    return Column(
      children: [
        const Spacer(),
        ToriSpirit(stageIndex: ref.read(appProvider).growth.stageIndex, size: 150, accent: accent, sleeping: true),
        const SizedBox(height: AppSpace.s20),
        Text('토리가 잠들었습니다', style: AppType.title2),
        const SizedBox(height: AppSpace.s8),
        Text('각성 계약의 목표를 지키지 못했어요.\n골든타임 안에 해독제로 깨울 수 있어요.',
            textAlign: TextAlign.center, style: AppType.body1.copyWith(color: c.labelAlt)),
        const SizedBox(height: AppSpace.s20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s20, vertical: AppSpace.s12),
          decoration: BoxDecoration(color: c.fill, borderRadius: AppRadius.b14),
          child: Column(children: [
            Text('골든타임', style: AppType.label2.copyWith(color: c.labelAlt)),
            const SizedBox(height: 4),
            Text(_fmtRemain(rem), style: AppType.title3.copyWith(color: c.negative, fontWeight: FontWeight.w700)),
          ]),
        ),
        const Spacer(),
        if (canRevive)
          OclButton('해독제로 깨우기 (${life.antidotes}개)', onPressed: () {
            ref.read(appProvider.notifier).reviveWithAntidote();
            context.go('/home');
          })
        else
          Text('해독제가 없어요. 골든타임이 지나면 관으로 옮겨져요.',
              textAlign: TextAlign.center, style: AppType.body2.copyWith(color: c.labelAlt)),
      ],
    );
  }

  // ---- coffin: choose new spirit or inherit ----
  Widget _coffin(BuildContext context, AppColors c, Color accent, AppState app) {
    final r = app.coffin;
    final stageName = r != null ? SpiritStage.all[r.stageIndex.clamp(0, 9)].name : '토리';
    final h = (r?.totalMin ?? 0) ~/ 60, m = (r?.totalMin ?? 0) % 60;
    final bonus = r != null ? LifeEngine.inheritBonusXp(r) : 0;
    return ListView(
      children: [
        const SizedBox(height: AppSpace.s8),
        Center(child: Opacity(opacity: 0.5, child: ToriSpirit(stageIndex: r?.stageIndex ?? 0, size: 120, accent: accent, animate: false))),
        const SizedBox(height: AppSpace.s12),
        Center(child: Text('관 속의 ${r?.name ?? '토리'}', style: AppType.title3)),
        const SizedBox(height: AppSpace.s4),
        Center(child: Text('함께한 기록은 사라지지 않아요', style: AppType.body2.copyWith(color: c.labelAlt))),
        const SizedBox(height: AppSpace.s20),
        OclCard(
          child: Column(children: [
            _recRow(c, '마지막 단계', '$stageName · LV ${r?.level ?? 1}'),
            _recRow(c, '누적 공부', '$h시간 $m분'),
            _recRow(c, '함께한 세션', '${r?.totalSessions ?? 0}회'),
          ]),
        ),
        const SizedBox(height: AppSpace.s20),
        OclButton('기억을 계승해 새 정령 시작', onPressed: () {
          ref.read(appProvider.notifier).inheritMemory();
          context.go('/home');
        }),
        const SizedBox(height: 6),
        Center(child: Text('이전 정령의 경험으로 +$bonus XP에서 시작해요', style: AppType.caption1.copyWith(color: c.labelAlt))),
        const SizedBox(height: AppSpace.s12),
        OclButton('처음부터 새 정령 시작', ghost: true, onPressed: () {
          ref.read(appProvider.notifier).startNewSpirit();
          context.go('/home');
        }),
      ],
    );
  }

  Widget _safe(BuildContext context, AppColors c, Color accent, AppState app) {
    return Column(
      children: [
        const Spacer(),
        ToriSpirit(stageIndex: app.growth.stageIndex, size: 140, accent: accent),
        const SizedBox(height: AppSpace.s16),
        Text('토리는 무사해요', style: AppType.title3),
        const Spacer(),
        OclButton('홈으로', onPressed: () => context.go('/home')),
      ],
    );
  }

  Widget _recRow(AppColors c, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(k, style: AppType.body2.copyWith(color: c.labelAlt)),
          Text(v, style: AppType.body1.copyWith(color: c.labelNormal, fontWeight: FontWeight.w600)),
        ]),
      );

  String _fmtRemain(Duration d) {
    if (d == Duration.zero) return '0일 0시간';
    final days = d.inDays;
    final hours = d.inHours % 24;
    final mins = d.inMinutes % 60;
    if (days > 0) return '$days일 $hours시간';
    return '$hours시간 $mins분 ${d.inSeconds % 60}초';
  }
}
