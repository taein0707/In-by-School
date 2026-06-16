import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_providers.dart';
import '../../app/settings_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/growth/growth.dart';
import '../../domain/spirit/spirit_stage.dart';
import '../../shared/widgets/tori_spirit.dart';

/// 성장 — 학습 여정의 시각화. 진화 단계 · 해금 능력 · 토리가 배운 것 · 함께한 시간.
class GrowthPage extends ConsumerWidget {
  const GrowthPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final accent = ref.watch(settingsProvider).accent;
    final g = ref.watch(appProvider).growth;
    final cur = g.stageIndex;
    final hours = g.totalMin ~/ 60, mins = g.totalMin % 60;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text('정령 진화 기록', style: AppType.headline2),
        leading: IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => Navigator.maybePop(context)),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s24),
          children: [
            const SizedBox(height: AppSpace.s8),
            Center(child: ToriSpirit(stageIndex: cur, size: 130, accent: accent)),
            const SizedBox(height: AppSpace.s4),
            Center(child: Text('${g.stage.name} · LV ${g.level}', style: AppType.headline2.copyWith(color: c.labelNeutral))),
            const SizedBox(height: AppSpace.s12),
            Container(
              padding: const EdgeInsets.all(AppSpace.s16),
              decoration: BoxDecoration(color: c.accentSoft, borderRadius: AppRadius.b16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _kv(context, '함께한 시간', '$hours시간 $mins분'),
                  const SizedBox(height: 8),
                  _kv(context, '토리가 배운 것', g.stage.learned),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.s20),
            // timeline: archive (top) → egg (bottom)
            for (int i = SpiritStage.all.length - 1; i >= 0; i--)
              _StageRow(
                stage: SpiritStage.all[i],
                state: i < cur ? _RowState.done : (i == cur ? _RowState.current : _RowState.locked),
                growth: g,
                onTap: () => _showDetail(context, ref, SpiritStage.all[i], i <= cur),
              ),
            const SizedBox(height: AppSpace.s24),
          ],
        ),
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 92, child: Text(k, style: AppType.label2.copyWith(color: context.c.labelAlt))),
          Expanded(child: Text(v, style: AppType.body2.copyWith(color: context.c.labelNeutral, fontWeight: FontWeight.w500))),
        ],
      );

  void _showDetail(BuildContext context, WidgetRef ref, SpiritStage st, bool reached) {
    final c = context.c;
    final accent = ref.read(settingsProvider).accent;
    showModalBottomSheet(
      context: context,
      backgroundColor: c.bgElevated,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: AppRadius.r24)),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpace.s24, AppSpace.s24, AppSpace.s24, AppSpace.s32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ToriSpirit(stageIndex: st.index, size: 130, accent: accent, animate: false),
            const SizedBox(height: AppSpace.s8),
            Text('${st.name}  ', style: AppType.title3),
            Text(st.isFinal ? 'LV ${st.levelMin}+' : 'LV ${st.levelMin}–${st.levelMax}',
                style: AppType.label2.copyWith(color: c.labelAlt)),
            const SizedBox(height: AppSpace.s12),
            Text(st.lore, textAlign: TextAlign.center, style: AppType.body1.copyWith(color: c.labelNeutral)),
            const SizedBox(height: AppSpace.s16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpace.s14),
              decoration: BoxDecoration(color: c.accentSoft, borderRadius: AppRadius.b12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('토리가 배우는 것', style: AppType.label2.copyWith(color: c.accent, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(st.learned, style: AppType.body2.copyWith(color: c.labelNeutral)),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.s12),
            Text('“${st.sampleLine}”',
                textAlign: TextAlign.center, style: AppType.body2.copyWith(color: c.labelAlt)),
          ],
        ),
      ),
    );
  }
}

enum _RowState { done, current, locked }

class _StageRow extends StatelessWidget {
  final SpiritStage stage;
  final _RowState state;
  final GrowthState growth;
  final VoidCallback onTap;
  const _StageRow({required this.stage, required this.state, required this.growth, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final isCur = state == _RowState.current;
    final locked = state == _RowState.locked;
    final color = isCur ? c.accent : (locked ? c.labelAssistive : c.labelNeutral);

    final row = InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(border: Border(left: BorderSide(color: isCur ? c.accent : c.lineAlt, width: 2))),
        child: Padding(
          padding: const EdgeInsets.only(left: AppSpace.s16),
          child: Row(
            children: [
              Icon(isCur ? Icons.play_arrow : (locked ? Icons.lock_outline : Icons.check_circle),
                  size: 16, color: color),
              const SizedBox(width: AppSpace.s10),
              Text(stage.name, style: AppType.body1.copyWith(color: color, fontWeight: isCur ? FontWeight.w700 : FontWeight.w500)),
              const Spacer(),
              Text(locked ? 'LV ${stage.levelMin}' : '달성', style: AppType.label2.copyWith(color: isCur ? c.accent : c.labelAssistive)),
            ],
          ),
        ),
      ),
    );

    if (!isCur) return row;

    // current node also shows the next-evolution preview
    final nextStage = SpiritStage.all[(stage.index + 1).clamp(0, SpiritStage.all.length - 1)];
    final nextMax = Growth.xpToNext(growth.level);
    final pct = (growth.xp / nextMax * 100).round();
    return Column(
      children: [
        row,
        Container(
          margin: const EdgeInsets.only(left: AppSpace.s8, bottom: AppSpace.s4),
          padding: const EdgeInsets.all(AppSpace.s14),
          decoration: BoxDecoration(
            color: c.accentSoft,
            border: Border(left: BorderSide(color: c.accent, width: 2)),
            borderRadius: const BorderRadius.horizontal(right: AppRadius.r12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('지금 · LV ${growth.level} · XP $pct%', style: AppType.label2.copyWith(color: c.accent, fontWeight: FontWeight.w700)),
              if (!stage.isFinal) ...[
                const SizedBox(height: AppSpace.s10),
                Row(children: [
                  Opacity(opacity: 0.5, child: ToriSpirit(stageIndex: nextStage.index, size: 48, accent: c.accent, animate: false)),
                  const SizedBox(width: AppSpace.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('다음: ${nextStage.name} (LV ${nextStage.levelMin})',
                            style: AppType.label1.copyWith(color: c.labelNormal, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text('해금: ${nextStage.learned}', style: AppType.caption1.copyWith(color: c.labelNeutral)),
                      ],
                    ),
                  ),
                ]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
