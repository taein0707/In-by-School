import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/aiquestion_providers.dart';
import '../../app/app_providers.dart';
import '../../app/flashcard_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/study/study_mode.dart';
import '../../domain/study/study_session.dart';
import '../../shared/widgets/ui.dart';
import 'session_config.dart';

/// 스터디 탭(P1-2) — OCL 학습 허브.
/// 인사 · 오늘 학습 현황 · 학습 시작(CTA) · 집중 학습(타이머) · 오늘의 복습 · 최근 학습.
class StudyHubPage extends ConsumerWidget {
  const StudyHubPage({super.key});

  static bool _isToday(DateTime d) {
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final app = ref.watch(appProvider);
    final g = app.growth;

    final due = ref.watch(dueReviewCountProvider);

    // 오늘 완료 문제 수
    final results = ref.watch(myQuestionResultsProvider).valueOrNull ?? const {};
    final quizDoneToday =
        results.values.where((r) => r.completedAt != null && _isToday(r.completedAt!)).length;

    // 오늘 복습한 카드 수(SRS lastReviewedAt 기준)
    final progress = ref.watch(myFlashcardProgressProvider).valueOrNull ?? const {};
    var reviewedToday = 0;
    for (final p in progress.values) {
      for (final r in p.reviews.values) {
        if (r.lastReviewedAt != null && _isToday(r.lastReviewedAt!)) reviewedToday++;
      }
    }

    final recent = [...app.sessions].reversed.take(5).toList();

    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.all(AppSpace.s20),
        children: [
          // 상단 인사
          Text('안녕하세요 👋', style: AppType.title2.copyWith(color: c.labelNormal)),
          const SizedBox(height: 4),
          Text('오늘도 목표를 향해 한 걸음 더 나아가 보세요.', style: AppType.body2.copyWith(color: c.labelAlt)),
          const SizedBox(height: AppSpace.s20),

          // 오늘 학습 현황 (2x2)
          const SectionLabel('오늘 학습 현황'),
          Row(children: [
            _statCard(context, Icons.timer_outlined, _fmtMin(g.todayMin), '오늘 공부'),
            const SizedBox(width: AppSpace.s8),
            _statCard(context, Icons.local_fire_department_outlined, '${g.streakCurrent}일', '연속 학습'),
          ]),
          const SizedBox(height: AppSpace.s8),
          Row(children: [
            _statCard(context, Icons.smart_toy_outlined, '$quizDoneToday개', '완료 문제'),
            const SizedBox(width: AppSpace.s8),
            _statCard(context, Icons.style_outlined, '$reviewedToday개', '복습 카드'),
          ]),
          const SizedBox(height: AppSpace.s24),

          // 학습 시작 CTA
          OclButton('학습 시작', onPressed: () => _openStartSheet(context)),
          const SizedBox(height: AppSpace.s24),

          // 집중 학습(타이머 프리셋)
          const SectionLabel('집중 학습'),
          Wrap(
            spacing: AppSpace.s8,
            runSpacing: AppSpace.s8,
            children: [
              _focusChip(context, '25분', 25),
              _focusChip(context, '30분', 30),
              _focusChip(context, '50분', 50),
              _Chip(label: '사용자 지정', onTap: () => context.push('/study/setup')),
            ],
          ),
          const SizedBox(height: AppSpace.s24),

          // 오늘의 복습
          const SectionLabel('오늘의 복습'),
          Container(
            padding: const EdgeInsets.all(AppSpace.s16),
            decoration: BoxDecoration(
              color: due > 0 ? c.accentSoft : c.bgElevated,
              borderRadius: AppRadius.b16,
              border: Border.all(color: due > 0 ? c.accent.withValues(alpha: 0.4) : c.lineAlt),
            ),
            child: Row(children: [
              Icon(Icons.replay_circle_filled_outlined, size: 28, color: due > 0 ? c.accent : c.labelAssistive),
              const SizedBox(width: AppSpace.s12),
              Expanded(
                child: Text(due > 0 ? '오늘 복습 $due개' : '오늘 복습할 카드가 없어요',
                    style: AppType.headline2.copyWith(color: due > 0 ? c.labelNormal : c.labelAlt)),
              ),
              if (due > 0)
                FilledButton(
                  onPressed: () => context.push('/review'),
                  style: FilledButton.styleFrom(
                      backgroundColor: c.accent, shape: RoundedRectangleBorder(borderRadius: AppRadius.b14)),
                  child: Text('복습하기', style: AppType.label1.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
            ]),
          ),
          const SizedBox(height: AppSpace.s24),

          // 최근 학습
          if (recent.isNotEmpty) ...[
            const SectionLabel('최근 학습'),
            ...recent.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.s8),
                  child: _recentTile(context, s),
                )),
          ],
        ],
      ),
    );
  }

  // ---- 학습 시작 BottomSheet ----
  void _openStartSheet(BuildContext context) {
    final c = context.c;
    showModalBottomSheet(
      context: context,
      backgroundColor: c.bgElevated,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: AppRadius.r24)),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.s20, AppSpace.s20, AppSpace.s20, AppSpace.s24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('무엇을 학습할까요?', style: AppType.title3),
              const SizedBox(height: AppSpace.s16),
              _startOption(sheetCtx, Icons.style_outlined, '카드 학습', '단어를 플래시카드로 외워요', '/vocab'),
              _startOption(sheetCtx, Icons.smart_toy_outlined, 'AI 문제', '배포된 문제를 풀어요', '/quizzes'),
              _startOption(sheetCtx, Icons.replay_outlined, '복습 시작', '오늘 복습 카드를 풀어요', '/review'),
              _startOption(sheetCtx, Icons.description_outlined, '온라인 학습지', '준비 중이에요', null),
            ],
          ),
        ),
      ),
    );
  }

  Widget _startOption(BuildContext sheetCtx, IconData icon, String title, String subtitle, String? path) {
    final c = sheetCtx.c;
    final enabled = path != null;
    return ListTile(
      leading: Icon(icon, color: enabled ? c.accent : c.labelAssistive),
      title: Text(title, style: AppType.body1.copyWith(color: enabled ? c.labelNormal : c.labelAlt)),
      subtitle: Text(subtitle, style: AppType.caption1.copyWith(color: c.labelAssistive)),
      trailing: enabled ? Icon(Icons.chevron_right, color: c.labelAssistive) : null,
      onTap: () {
        Navigator.pop(sheetCtx);
        if (enabled) {
          sheetCtx.push(path);
        } else {
          ScaffoldMessenger.of(sheetCtx).showSnackBar(const SnackBar(content: Text('곧 만나요 — 준비 중인 기능이에요.')));
        }
      },
    );
  }

  // ---- 집중 학습 프리셋 → 기존 학습 화면(free 모드 + 목표분) ----
  Widget _focusChip(BuildContext context, String label, int minutes) => _Chip(
        label: label,
        onTap: () => context.push(
          '/study/active',
          extra: SessionConfig(mode: StudyMode.free, subject: '집중 학습', goalMin: minutes),
        ),
      );

  Widget _statCard(BuildContext context, IconData icon, String value, String label) {
    final c = context.c;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpace.s14),
        decoration: BoxDecoration(color: c.bgElevated, borderRadius: AppRadius.b14, border: Border.all(color: c.lineAlt)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 20, color: c.accent),
          const SizedBox(height: AppSpace.s8),
          Text(value, style: AppType.headline1.copyWith(color: c.labelNormal)),
          const SizedBox(height: 2),
          Text(label, style: AppType.caption1.copyWith(color: c.labelAlt)),
        ]),
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
        Text(_ago(s.date), style: AppType.body2.copyWith(color: c.labelAlt)),
      ]),
    );
  }

  String _fmtMin(int min) => min < 60 ? '$min분' : '${min ~/ 60}시간 ${min % 60}분';

  String _ago(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: c.fill,
      borderRadius: AppRadius.bFull,
      child: InkWell(
        borderRadius: AppRadius.bFull,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(label, style: AppType.label1.copyWith(color: c.labelNeutral)),
        ),
      ),
    );
  }
}
