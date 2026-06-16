import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/battle_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/battle/battle.dart';
import '../../domain/battle/battle_engine.dart';
import '../../shared/widgets/ui.dart';

/// 결과 발표 — 상위 3명 시상대(이름 마스킹). 최종 발표이므로 1~3위만 공개하고
/// 그 외 등수는 노출하지 않는다.
class BattleResultPage extends ConsumerWidget {
  final String battleId;
  const BattleResultPage({super.key, required this.battleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final players = ref.watch(battlePlayersProvider(battleId)).value ?? const [];
    final top = players.take(3).toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text('결과 발표', style: AppType.headline2),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s24),
          child: Column(
            children: [
              const SizedBox(height: AppSpace.s12),
              Text('🏆 단어 경쟁전 결과', style: AppType.title2),
              const SizedBox(height: AppSpace.s24),
              if (top.isEmpty)
                Expanded(child: Center(child: Text('참가 기록이 없어요.', style: AppType.body1.copyWith(color: c.labelAlt))))
              else
                Expanded(
                  child: ListView(
                    children: [
                      for (var i = 0; i < top.length; i++) _podiumRow(context, i + 1, top[i]),
                    ],
                  ),
                ),
              OclButton('확인', onPressed: () => context.go('/home')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _podiumRow(BuildContext context, int rank, BattlePlayer p) {
    final c = context.c;
    final medal = switch (rank) {
      1 => '🥇',
      2 => '🥈',
      _ => '🥉',
    };
    final tint = switch (rank) {
      1 => c.accent,
      _ => c.labelAlt,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s12),
      child: Container(
        padding: const EdgeInsets.all(AppSpace.s16),
        decoration: BoxDecoration(
          color: rank == 1 ? c.accentSoft : c.bgElevated,
          borderRadius: AppRadius.b16,
          border: Border.all(color: rank == 1 ? c.accent.withValues(alpha: 0.4) : c.lineAlt),
        ),
        child: Row(
          children: [
            Text(medal, style: const TextStyle(fontSize: 30)),
            const SizedBox(width: AppSpace.s12),
            Text('$rank위', style: AppType.headline2.copyWith(color: tint, fontWeight: FontWeight.w800)),
            const SizedBox(width: AppSpace.s12),
            Expanded(
              child: Text(BattleEngine.maskName(p.nickname),
                  style: AppType.title3.copyWith(color: c.labelNormal)),
            ),
            Text('${p.score}점', style: AppType.headline2.copyWith(color: c.labelNeutral)),
          ],
        ),
      ),
    );
  }
}
