import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/battle_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/battle/battle.dart';
import '../../shared/widgets/ui.dart';

/// 교사 라이브 — 참가 코드 안내 + 실시간 참여/연속정답 이벤트. 순위 숫자는 학생에게
/// 노출하지 않으며, 이 화면은 교사용이라 점수/연속을 보여준다.
class BattleLivePage extends ConsumerStatefulWidget {
  final String battleId;
  const BattleLivePage({super.key, required this.battleId});
  @override
  ConsumerState<BattleLivePage> createState() => _BattleLivePageState();
}

class _BattleLivePageState extends ConsumerState<BattleLivePage> {
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
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
    final battle = ref.watch(battleProvider(widget.battleId)).value;
    final players = ref.watch(battlePlayersProvider(widget.battleId)).value ?? const [];

    if (battle == null) {
      return Scaffold(appBar: _bar(context, '경쟁전'), body: Center(child: CircularProgressIndicator(color: c.accent)));
    }

    int? remaining;
    if (!battle.unlimitedTime && battle.startAt != null && battle.status == BattleStatus.running) {
      final end = battle.startAt!.add(Duration(seconds: battle.timeLimitSec));
      remaining = end.difference(_now).inSeconds;
      if (remaining < 0) remaining = 0;
    }
    final nearEnd = remaining != null && remaining <= 60 && remaining > 0;
    final events = _events(players, nearEnd, players.length >= 2);

    return Scaffold(
      appBar: _bar(context, battle.title.isEmpty ? '단어 경쟁전' : battle.title),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(AppSpace.s20),
          children: [
            // 참가 코드
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpace.s20),
              decoration: BoxDecoration(color: c.accentSoft, borderRadius: AppRadius.b16),
              child: Column(children: [
                Text('참가 코드', style: AppType.label1.copyWith(color: c.labelAlt)),
                const SizedBox(height: AppSpace.s8),
                Text(battle.joinCode,
                    style: AppType.display3.copyWith(color: c.accent, letterSpacing: 6, fontWeight: FontWeight.w800)),
                const SizedBox(height: AppSpace.s8),
                Text('학생들이 “친구들과 학습 → 단어 경쟁전”에서 코드를 입력해요',
                    textAlign: TextAlign.center, style: AppType.body2.copyWith(color: c.labelNeutral)),
              ]),
            ),
            const SizedBox(height: AppSpace.s12),
            Row(children: [
              _stat(context, '${players.length}', '참가'),
              const SizedBox(width: AppSpace.s8),
              _stat(context, battle.unlimitedTime ? '∞' : _mmss(remaining ?? battle.timeLimitSec), '남은 시간'),
              const SizedBox(width: AppSpace.s8),
              _stat(context, '${battle.questionCount}', '문제'),
            ]),
            if (nearEnd) ...[
              const SizedBox(height: AppSpace.s12),
              _banner(context, c.negative, '🚨 종료 1분 전'),
            ],
            const SizedBox(height: AppSpace.s16),
            const SectionLabel('실시간'),
            if (events.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpace.s24),
                child: Center(child: Text('참가를 기다리고 있어요…', style: AppType.body2.copyWith(color: c.labelAlt))),
              )
            else
              ...events.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.s8),
                    child: _eventTile(context, e),
                  )),
            const SizedBox(height: AppSpace.s24),
            if (battle.status != BattleStatus.ended)
              OclButton('경쟁전 종료', onPressed: () async {
                await ref.read(battleRepositoryProvider).endBattle(widget.battleId);
                if (context.mounted) context.pushReplacement('/battle/result', extra: widget.battleId);
              })
            else
              OclButton('결과 보기', onPressed: () => context.pushReplacement('/battle/result', extra: widget.battleId)),
          ],
        ),
      ),
    );
  }

  List<String> _events(List<BattlePlayer> players, bool nearEnd, bool many) {
    final out = <String>[];
    // 연속 정답(높은 순) → 참가 순.
    final byStreak = [...players]..sort((a, b) => b.streak.compareTo(a.streak));
    for (final p in byStreak.where((p) => p.streak >= 5).take(4)) {
      out.add('🔥 ${p.nickname} ${p.streak}연속');
    }
    if (many) out.add('⚡ 상위권 경쟁 시작');
    final joins = [...players]..sort((a, b) => (b.joinedAt ?? DateTime(0)).compareTo(a.joinedAt ?? DateTime(0)));
    for (final p in joins.take(6)) {
      out.add('✨ ${p.nickname} 참가');
    }
    return out;
  }

  Widget _eventTile(BuildContext context, String text) {
    final c = context.c;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16, vertical: AppSpace.s12),
      decoration: BoxDecoration(color: c.bgElevated, borderRadius: AppRadius.b14, border: Border.all(color: c.lineAlt)),
      child: Text(text, style: AppType.body1.copyWith(color: c.labelNeutral)),
    );
  }

  Widget _banner(BuildContext context, Color color, String text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpace.s12),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: AppRadius.b14),
        child: Text(text, textAlign: TextAlign.center, style: AppType.headline2.copyWith(color: color)),
      );

  Widget _stat(BuildContext context, String value, String label) {
    final c = context.c;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: BoxDecoration(color: c.bgAlt, borderRadius: AppRadius.b14),
        child: Column(children: [
          Text(value, style: AppType.headline2.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label, style: AppType.caption1.copyWith(color: c.labelAlt)),
        ]),
      ),
    );
  }

  String _mmss(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  PreferredSizeWidget _bar(BuildContext context, String title) => AppBar(
        backgroundColor: context.c.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => context.pop()),
        title: Text(title, style: AppType.headline1),
      );
}
