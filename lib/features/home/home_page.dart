import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/account_providers.dart';
import '../../app/aiquestion_providers.dart';
import '../../app/app_providers.dart';
import '../../app/assignment_providers.dart';
import '../../app/flashcard_providers.dart';
import '../../app/settings_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/analytics/analytics.dart';
import '../../domain/life/life.dart';
import '../../domain/study/study_mode.dart';
import '../../domain/study/study_session.dart';
import '../../shared/widgets/tori_spirit.dart';
import '../../shared/widgets/ui.dart';

/// 홈 — 정보 중심 대시보드(P1). 인사 · 오늘 해야 할 일 · 공부 시간 · 최근 기록.
/// 토리/성장은 보상 지표로 유지(작게), 각성 계약도 보존.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(appProvider.notifier).tickLife());

    final c = context.c;
    final app = ref.watch(appProvider);
    final accent = ref.watch(settingsProvider).accent;
    final g = app.growth;
    final life = app.life;

    if (life.isDead) return _deadHome(context, ref, c, accent, g, life);

    final name = ref.watch(currentProfileProvider).valueOrNull?.displayName ?? '';
    final oneLiner = Analytics.homeOneLiner(app.sessions, g);

    // 오늘 해야 할 일 — 모든 비동기는 valueOrNull 로 안전 접근(AsyncError rethrow 방지).
    final assignments = ref.watch(studentAssignmentsProvider).valueOrNull ?? const [];
    final subs = ref.watch(mySubmissionsProvider).valueOrNull ?? const {};
    final hwTodo = assignments.where((a) => !(subs[a.id]?.isDone ?? false)).length;

    final sets = ref.watch(studentQuestionSetsProvider).valueOrNull ?? const [];
    final results = ref.watch(myQuestionResultsProvider).valueOrNull ?? const {};
    final quizTodo = sets.where((s) => !results.containsKey(s.id)).length;

    final reviewTodo = ref.watch(dueReviewCountProvider);

    final recent = [...app.sessions].reversed.take(3).toList();

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppSpace.s24, AppSpace.s12, AppSpace.s24, AppSpace.s24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (life.contractActive) ...[
                _ContractBanner(life: life, todayMin: g.todayMin),
                const SizedBox(height: AppSpace.s16),
              ],
              Text(_greeting(name), style: AppType.title2.copyWith(color: c.labelNormal)),
              const SizedBox(height: AppSpace.s6),
              Text('“$oneLiner”', style: AppType.body2.copyWith(color: c.labelAlt)),
              const SizedBox(height: AppSpace.s16),

              // 토리(보상 지표) — 작게, 탭하면 성장 페이지로.
              Center(
                child: GestureDetector(
                  onTap: () => context.push('/growth'),
                  child: Column(children: [
                    ToriSpirit(stageIndex: g.stageIndex, size: 96, accent: accent),
                    const SizedBox(height: AppSpace.s4),
                    Text('${g.stage.name} · LV ${g.level}', style: AppType.body2.copyWith(color: c.labelAlt)),
                  ]),
                ),
              ),
              const SizedBox(height: AppSpace.s20),

              const SectionLabel('오늘 해야 할 일'),
              Row(children: [
                _todo(context, '숙제', hwTodo, Icons.assignment_outlined, () => context.push('/assignments')),
                const SizedBox(width: AppSpace.s8),
                _todo(context, '문제', quizTodo, Icons.smart_toy_outlined, () => context.push('/quizzes')),
                const SizedBox(width: AppSpace.s8),
                _todo(context, '복습', reviewTodo, Icons.style_outlined, () => context.push('/review')),
              ]),
              const SizedBox(height: AppSpace.s16),

              // 오늘 공부 시간 + 연속일
              Container(
                padding: const EdgeInsets.all(AppSpace.s16),
                decoration: BoxDecoration(color: c.bgElevated, borderRadius: AppRadius.b16, border: Border.all(color: c.lineAlt)),
                child: Row(children: [
                  Icon(Icons.timer_outlined, color: c.accent),
                  const SizedBox(width: AppSpace.s12),
                  Expanded(child: Text('오늘 공부 시간', style: AppType.body1.copyWith(color: c.labelNeutral))),
                  Text(_fmtMin(g.todayMin), style: AppType.headline2.copyWith(color: c.labelNormal)),
                  const SizedBox(width: AppSpace.s12),
                  Text('연속 ${g.streakCurrent}일', style: AppType.body2.copyWith(color: c.labelAlt)),
                ]),
              ),
              const SizedBox(height: AppSpace.s20),

              if (recent.isNotEmpty) ...[
                const SectionLabel('최근 학습 기록'),
                ...recent.map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.s8),
                      child: _recentTile(context, s),
                    )),
              ],

              if (!life.contractActive) ...[
                const SizedBox(height: AppSpace.s4),
                TextButton(
                  onPressed: () => _openContractSheet(context, ref),
                  child: Text('시험기간 · 각성 계약 시작', style: AppType.label1.copyWith(color: c.accent)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _greeting(String name) {
    final h = DateTime.now().hour;
    final g = h < 6
        ? '아직 늦은 밤이야'
        : h < 12
            ? '좋은 아침이야'
            : h < 18
                ? '좋은 오후야'
                : '좋은 저녁이야';
    return name.isEmpty ? '$g 👋' : '$name님, $g 👋';
  }

  String _fmtMin(int min) {
    if (min < 60) return '$min분';
    return '${min ~/ 60}시간 ${min % 60}분';
  }

  Widget _todo(BuildContext context, String label, int count, IconData icon, VoidCallback onTap) {
    final c = context.c;
    final has = count > 0;
    return Expanded(
      child: Material(
        color: has ? c.accentSoft : c.bgElevated,
        borderRadius: AppRadius.b14,
        child: InkWell(
          borderRadius: AppRadius.b14,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.s14, horizontal: AppSpace.s8),
            decoration: BoxDecoration(
              borderRadius: AppRadius.b14,
              border: Border.all(color: has ? c.accent.withValues(alpha: 0.4) : c.lineAlt),
            ),
            child: Column(children: [
              Icon(icon, size: 22, color: has ? c.accent : c.labelAssistive),
              const SizedBox(height: 6),
              Text('$count개', style: AppType.headline2.copyWith(color: has ? c.labelNormal : c.labelAlt)),
              const SizedBox(height: 2),
              Text(label, style: AppType.caption1.copyWith(color: c.labelAlt)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _recentTile(BuildContext context, StudySession s) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(AppSpace.s14),
      decoration: BoxDecoration(color: c.bgElevated, borderRadius: AppRadius.b14, border: Border.all(color: c.lineAlt)),
      child: Row(children: [
        Icon(Icons.check_circle_outline, size: 20, color: c.positive),
        const SizedBox(width: AppSpace.s12),
        Expanded(
          child: Text('${s.subject} · ${StudyModeInfo.of(s.mode).name}',
              style: AppType.body1.copyWith(color: c.labelNeutral)),
        ),
        Text('${s.focusedMin}분', style: AppType.body2.copyWith(color: c.labelAlt)),
      ]),
    );
  }

  Widget _deadHome(BuildContext context, WidgetRef ref, AppColors c, Color accent, dynamic g, Life life) {
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ToriSpirit(stageIndex: g.stageIndex, size: 160, accent: accent, sleeping: true),
              const SizedBox(height: AppSpace.s20),
              Text('토리가 잠들었어요', style: AppType.title2),
              const SizedBox(height: AppSpace.s8),
              Text(life.state == LifeState.coffin
                  ? '골든타임이 지났어요. 토리를 돌봐주세요.'
                  : '각성 계약의 목표를 지키지 못했어요.',
                  textAlign: TextAlign.center, style: AppType.body1.copyWith(color: c.labelAlt)),
              const SizedBox(height: AppSpace.s24),
              OclButton('토리 돌보기', onPressed: () => context.push('/life')),
            ],
          ),
        ),
      ),
    );
  }

  void _openContractSheet(BuildContext context, WidgetRef ref) {
    int dday = 14;
    int daily = 120;
    showModalBottomSheet(
      context: context,
      backgroundColor: context.c.bgElevated,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: AppRadius.r24)),
      builder: (sheetCtx) {
        final c = sheetCtx.c;
        return StatefulBuilder(
          builder: (ctx, setSheet) => Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.s24, AppSpace.s24, AppSpace.s24, AppSpace.s32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('각성 계약', style: AppType.title3),
                const SizedBox(height: AppSpace.s8),
                Text('시험기간 동안 XP가 2.5배로 들어와요.\n단, 하루 목표를 며칠 놓치면 토리가 위험해져요.',
                    style: AppType.body2.copyWith(color: c.labelAlt)),
                const SizedBox(height: AppSpace.s20),
                _sheetStepper(ctx, '시험까지', '$dday일',
                    () => setSheet(() => dday = (dday - 1).clamp(1, 200)),
                    () => setSheet(() => dday = (dday + 1).clamp(1, 200))),
                _sheetStepper(ctx, '하루 목표', '$daily분',
                    () => setSheet(() => daily = (daily - 10).clamp(30, 480)),
                    () => setSheet(() => daily = (daily + 10).clamp(30, 480))),
                const SizedBox(height: AppSpace.s24),
                OclButton('계약 시작', onPressed: () {
                  ref.read(appProvider.notifier).activateContract(
                        examDate: DateTime.now().add(Duration(days: dday)),
                        dailyTargetMin: daily,
                      );
                  Navigator.pop(sheetCtx);
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sheetStepper(BuildContext context, String label, String value, VoidCallback onMinus, VoidCallback onPlus) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppType.body1.copyWith(color: c.labelNeutral)),
          Row(children: [
            IconButton(onPressed: onMinus, icon: const Icon(Icons.remove_circle_outline)),
            SizedBox(width: 64, child: Text(value, textAlign: TextAlign.center, style: AppType.headline2)),
            IconButton(onPressed: onPlus, icon: const Icon(Icons.add_circle_outline)),
          ]),
        ],
      ),
    );
  }
}

class _ContractBanner extends StatelessWidget {
  final Life life;
  final int todayMin;
  const _ContractBanner({required this.life, required this.todayMin});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final danger = life.state == LifeState.danger;
    final dday = life.examDate != null
        ? life.examDate!.difference(DateTime.now()).inDays.clamp(0, 999)
        : 0;
    final progress = (todayMin / life.dailyTargetMin).clamp(0.0, 1.0);
    final tint = danger ? c.negative : c.accent;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpace.s16),
      decoration: BoxDecoration(
        color: danger ? c.negative.withValues(alpha: 0.08) : c.accentSoft,
        borderRadius: AppRadius.b16,
        border: Border.all(color: tint.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('각성 계약 · D-$dday', style: AppType.label1.copyWith(color: tint, fontWeight: FontWeight.w700)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: tint, borderRadius: AppRadius.bFull),
              child: Text('XP 2.5x', style: AppType.caption2.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: AppSpace.s10),
          Row(children: [
            Expanded(
              child: ClipRRect(
                borderRadius: AppRadius.bFull,
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: c.fillStrong,
                  valueColor: AlwaysStoppedAnimation(tint),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text('$todayMin/${life.dailyTargetMin}분', style: AppType.caption1.copyWith(color: c.labelNeutral)),
          ]),
          const SizedBox(height: AppSpace.s10),
          Row(children: [
            for (int i = 0; i < Life.maxHealth; i++)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(i < life.health ? Icons.favorite : Icons.favorite_border, size: 16, color: tint),
              ),
            const Spacer(),
            if (danger) Text('위험 — 오늘 목표를 채워주세요', style: AppType.caption1.copyWith(color: c.negative)),
          ]),
        ],
      ),
    );
  }
}
