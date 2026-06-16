import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_providers.dart';
import '../../app/settings_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/analytics/analytics.dart';
import '../../domain/growth/growth.dart';
import '../../domain/spirit/spirit_stage.dart';
import '../../shared/widgets/tori_spirit.dart';
import '../../shared/widgets/ui.dart';

/// 결과 — 공부 시간 · XP · 레벨 · 진화 여부 · AI 피드백 · 모드별 분석.
class StudyResultPage extends ConsumerWidget {
  const StudyResultPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final accent = ref.watch(settingsProvider).accent;
    final app = ref.watch(appProvider);
    final r = app.lastResult;
    final g = app.growth;

    if (r == null) {
      return Scaffold(body: Center(child: OclButton('홈으로', onPressed: () => context.go('/home'))));
    }

    // 0분 중단 → 차분한 휴식 화면
    if (r.abandoned && r.gain.focusedMin < 1) {
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.s24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ToriSpirit(stageIndex: g.stageIndex, size: 150, accent: accent, sleeping: true),
                const SizedBox(height: AppSpace.s20),
                Text('쉬어가도 괜찮아요', style: AppType.title2),
                const SizedBox(height: AppSpace.s8),
                Text('오늘은 여기까지. 내일 다시 만나요.',
                    style: AppType.body1.copyWith(color: c.labelAlt)),
                const Spacer(),
                OclButton('확인', onPressed: () => context.go('/home')),
              ],
            ),
          ),
        ),
      );
    }

    final stage = g.stage;
    final feedback = Analytics.resultFeedback(r.gain, r.session, g);
    final xpMax = Growth.xpToNext(g.level);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpace.s24, AppSpace.s8, AppSpace.s24, AppSpace.s16),
                children: [
                  if (r.gain.stageUp && !r.abandoned)
                    _banner(context, '✦ 진화! ${SpiritStage.all[r.gain.afterStage].name} ✦', c.accentSoft, c.accent)
                  else if (r.gain.leveledUp > 0 && !r.abandoned)
                    _banner(context, '레벨 ${g.level} 달성', c.fill, c.labelNeutral),
                  const SizedBox(height: AppSpace.s8),
                  Center(
                    child: ToriSpirit(
                      stageIndex: g.stageIndex,
                      size: 150,
                      accent: accent,
                      levelUp: r.gain.leveledUp > 0 && !r.abandoned,
                    ),
                  ),
                  const SizedBox(height: AppSpace.s4),
                  Center(child: Text('${stage.name} · LV ${g.level}',
                      style: AppType.headline2.copyWith(color: c.labelNeutral))),
                  const SizedBox(height: AppSpace.s16),
                  Row(children: [
                    _stat(context, '${r.gain.focusedMin}', '분 집중'),
                    const SizedBox(width: AppSpace.s8),
                    _stat(context, '+${r.gain.xp}', 'XP'),
                    const SizedBox(width: AppSpace.s8),
                    _stat(context, '${g.streakCurrent}', '일 연속'),
                  ]),
                  const SizedBox(height: AppSpace.s12),
                  _xpBar(context, g.xp / xpMax, xpMax - g.xp),
                  const SizedBox(height: AppSpace.s16),
                  OclCard(
                    color: c.accentSoft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${g.name}의 피드백', style: AppType.headline2),
                        const SizedBox(height: AppSpace.s8),
                        ...feedback.map((f) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(f, style: AppType.body1.copyWith(color: c.labelNeutral)),
                            )),
                      ],
                    ),
                  ),
                  if (r.blank != null) ...[
                    const SizedBox(height: AppSpace.s12),
                    _blankCard(context, r.blank!),
                  ],
                  if (r.quiz != null) ...[
                    const SizedBox(height: AppSpace.s12),
                    _quizCard(context, r.quiz!),
                  ],
                  if (r.reviewDates != null) ...[
                    const SizedBox(height: AppSpace.s12),
                    _reviewCard(context, r.reviewDates!),
                  ],
                  if (r.examPlan != null) ...[
                    const SizedBox(height: AppSpace.s12),
                    _examCard(context, r.examPlan!),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.s24, 0, AppSpace.s24, AppSpace.s12),
              child: OclButton('확인', onPressed: () => context.go('/home')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _banner(BuildContext context, String text, Color bg, Color fg) => Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(color: bg, borderRadius: AppRadius.bFull),
          child: Text(text, style: AppType.headline2.copyWith(color: fg)),
        ),
      );

  Widget _stat(BuildContext context, String value, String label) {
    final c = context.c;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(color: c.bgAlt, borderRadius: AppRadius.b14),
        child: Column(children: [
          Text(value, style: AppType.title3.copyWith(fontWeight: FontWeight.w700)),
          Text(label, style: AppType.caption1.copyWith(color: c.labelAlt)),
        ]),
      ),
    );
  }

  Widget _xpBar(BuildContext context, double p, int remain) {
    final c = context.c;
    return Column(children: [
      ClipRRect(
        borderRadius: AppRadius.bFull,
        child: LinearProgressIndicator(
          value: p.clamp(0, 1),
          minHeight: 10,
          backgroundColor: c.fillStrong,
          valueColor: AlwaysStoppedAnimation(c.accent),
        ),
      ),
      const SizedBox(height: 6),
      Text('다음 레벨까지 $remain XP', style: AppType.caption1.copyWith(color: c.labelAlt)),
    ]);
  }

  Widget _blankCard(BuildContext context, BlankAnalysis b) {
    final c = context.c;
    return OclCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('백지복습 AI 분석', style: AppType.headline2),
          const SizedBox(height: AppSpace.s12),
          Row(children: [
            SizedBox(width: 44, child: Text('이해도', style: AppType.label2.copyWith(color: c.labelAlt))),
            const SizedBox(width: 10),
            Expanded(
              child: ClipRRect(
                borderRadius: AppRadius.bFull,
                child: LinearProgressIndicator(
                  value: b.understanding / 100,
                  minHeight: 10,
                  backgroundColor: c.fillStrong,
                  valueColor: AlwaysStoppedAnimation(c.accent),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text('${b.understanding}%', style: AppType.label1.copyWith(color: c.accent, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: AppSpace.s12),
          if (b.understood.isNotEmpty) _bullets(context, '잘 이해한 개념', b.understood, c.positive),
          if (b.missing.isNotEmpty) _bullets(context, '보완 필요', b.missing, c.cautionary),
          _row(context, '설명 정확도', b.accuracy),
          _row(context, '복습 추천', b.review),
          if (b.nextStudy.isNotEmpty) _row(context, '토리의 제안', b.nextStudy),
        ],
      ),
    );
  }

  Widget _bullets(BuildContext context, String title, List<String> items, Color dot) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.s10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppType.label2.copyWith(color: c.labelNeutral, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          ...items.map((t) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(width: 5, height: 5, margin: const EdgeInsets.only(top: 7, right: 8),
                      decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
                  Expanded(child: Text(t, style: AppType.body2.copyWith(color: c.labelNeutral))),
                ]),
              )),
        ],
      ),
    );
  }

  Widget _quizCard(BuildContext context, QuizResult q) {
    final c = context.c;
    return OclCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('문제풀이 분석', style: AppType.headline2),
          const SizedBox(height: AppSpace.s12),
          Row(children: [
            SizedBox(width: 44, child: Text('정답률', style: AppType.label2.copyWith(color: c.labelAlt))),
            const SizedBox(width: 10),
            Expanded(
              child: ClipRRect(
                borderRadius: AppRadius.bFull,
                child: LinearProgressIndicator(
                  value: q.accuracy / 100,
                  minHeight: 10,
                  backgroundColor: c.fillStrong,
                  valueColor: AlwaysStoppedAnimation(c.accent),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text('${q.accuracy}%', style: AppType.label1.copyWith(color: c.accent, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: AppSpace.s10),
          Text(q.note, style: AppType.body2.copyWith(color: c.labelNeutral)),
        ],
      ),
    );
  }

  Widget _reviewCard(BuildContext context, List<DateTime> dates) {
    final c = context.c;
    const labels = ['1일 뒤', '3일 뒤', '7일 뒤'];
    return OclCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('복습 알림 예약', style: AppType.headline2),
          const SizedBox(height: 4),
          Text('망각곡선에 맞춰 토리가 다시 알려줄게요.', style: AppType.body2.copyWith(color: c.labelAlt)),
          const SizedBox(height: AppSpace.s12),
          for (int i = 0; i < dates.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Icon(Icons.notifications_none, size: 18, color: c.accent),
                const SizedBox(width: 8),
                Text(i < labels.length ? labels[i] : '복습', style: AppType.body1.copyWith(color: c.labelNeutral)),
                const Spacer(),
                Text('${dates[i].month}월 ${dates[i].day}일', style: AppType.label2.copyWith(color: c.labelAlt)),
              ]),
            ),
        ],
      ),
    );
  }

  Widget _examCard(BuildContext context, ExamPlan p) {
    final c = context.c;
    final h = p.dailyMin ~/ 60, m = p.dailyMin % 60;
    return OclCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('시험 대비 플랜 · D-${p.dday}', style: AppType.headline2),
          const SizedBox(height: AppSpace.s10),
          Row(children: [
            Text('하루 목표', style: AppType.body1.copyWith(color: c.labelNeutral)),
            const Spacer(),
            Text('${h > 0 ? '$h시간 ' : ''}${m > 0 ? '$m분' : ''}',
                style: AppType.headline2.copyWith(color: c.accent)),
          ]),
          const SizedBox(height: AppSpace.s10),
          Text('과목 비율', style: AppType.label2.copyWith(color: c.labelAlt)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: p.split
                .map((s) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: c.accentSoft, borderRadius: AppRadius.bFull),
                      child: Text(s, style: AppType.label2.copyWith(color: c.accent, fontWeight: FontWeight.w600)),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String title, String body) => Padding(
        padding: const EdgeInsets.only(top: AppSpace.s10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppType.label2.copyWith(color: context.c.labelNeutral, fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            Text(body, style: AppType.body2.copyWith(color: context.c.labelNeutral)),
          ],
        ),
      );
}
