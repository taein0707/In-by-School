import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/engagement_providers.dart';
import '../../app/worksheet_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/engagement/quiz_competition.dart';
import '../../domain/worksheet/worksheet.dart';
import '../../shared/widgets/ui.dart';

/// 퀴즈 대회 목록(P4-3) — 교사: 학습지 기반 생성/삭제, 학생: 참가.
class QuizListPage extends ConsumerWidget {
  final String classroomId;
  final String? classroomName;
  final bool teacher;
  const QuizListPage({super.key, required this.classroomId, this.classroomName, this.teacher = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final comps = ref.watch(classroomQuizzesProvider(classroomId)).valueOrNull ?? const [];

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => context.pop()),
        title: Text('퀴즈 대회', style: AppType.headline1),
      ),
      floatingActionButton: teacher
          ? FloatingActionButton.extended(
              backgroundColor: c.accent,
              onPressed: () => _openCreate(context, ref),
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text('대회 만들기', style: AppType.label1.copyWith(color: Colors.white)),
            )
          : null,
      body: SafeArea(
        child: comps.isEmpty
            ? _empty(context)
            : ListView(
                padding: const EdgeInsets.all(AppSpace.s20),
                children: [for (final q in comps) _card(context, ref, q)],
              ),
      ),
    );
  }

  Widget _card(BuildContext context, WidgetRef ref, QuizCompetition q) {
    final c = context.c;
    final status = switch (q.status) {
      QuizStatus.waiting => '대기',
      QuizStatus.playing => '진행 중',
      QuizStatus.finished => '종료',
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s8),
      child: InkWell(
        borderRadius: AppRadius.b16,
        onTap: () => context.push('/engage/quiz/${q.id}?t=${teacher ? 1 : 0}', extra: classroomName),
        child: OclCard(
          child: Row(children: [
            Icon(Icons.emoji_events_outlined, color: c.accent),
            const SizedBox(width: AppSpace.s12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(q.title.isEmpty ? '퀴즈 대회' : q.title, style: AppType.headline2),
                Text('${q.total}문제 · ${q.durationSec ~/ 60}분 · $status', style: AppType.body2.copyWith(color: c.labelAlt)),
              ]),
            ),
            if (teacher)
              IconButton(
                icon: Icon(Icons.delete_outline, color: c.labelAssistive),
                onPressed: () => ref.read(quizRepositoryProvider).deleteCompetition(q.id),
              )
            else
              Icon(Icons.chevron_right, color: c.labelAssistive),
          ]),
        ),
      ),
    );
  }

  void _openCreate(BuildContext context, WidgetRef ref) {
    final titleCtrl = TextEditingController();
    Worksheet? picked;
    var duration = 120;
    var maxAttempts = 1;
    var busy = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.c.bgElevated,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: AppRadius.r24)),
      builder: (sheetCtx) {
        final c = sheetCtx.c;
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            final worksheets = ref.watch(classroomWorksheetsProvider(classroomId)).valueOrNull ?? const [];
            return Padding(
              padding: EdgeInsets.fromLTRB(AppSpace.s20, AppSpace.s20, AppSpace.s20, MediaQuery.of(ctx).viewInsets.bottom + AppSpace.s24),
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('퀴즈 대회 만들기', style: AppType.title3),
                  const SizedBox(height: AppSpace.s16),
                  TextField(controller: titleCtrl, style: AppType.body1.copyWith(color: c.labelNormal), decoration: _dec(c, '제목 (예: 1단원 퀴즈)')),
                  const SizedBox(height: AppSpace.s16),
                  SectionLabel('문제 세트 (학습지 선택)'),
                  if (worksheets.isEmpty)
                    Text('이 교실에 학습지가 없어요. 먼저 학습지를 만들어 주세요.', style: AppType.body2.copyWith(color: c.labelAssistive))
                  else
                    Wrap(spacing: AppSpace.s8, runSpacing: AppSpace.s8, children: [
                      for (final w in worksheets)
                        ChoiceChip(
                          label: Text(w.title.isEmpty ? '학습지' : w.title,
                              style: AppType.label1.copyWith(color: picked?.id == w.id ? Colors.white : c.labelNeutral)),
                          selected: picked?.id == w.id,
                          onSelected: (_) => setSheet(() => picked = w),
                          selectedColor: c.accent,
                          backgroundColor: c.bg,
                          shape: RoundedRectangleBorder(borderRadius: AppRadius.b14, side: BorderSide(color: picked?.id == w.id ? c.accent : c.lineAlt)),
                        ),
                    ]),
                  const SizedBox(height: AppSpace.s16),
                  SectionLabel('제한 시간'),
                  Wrap(spacing: AppSpace.s8, children: [
                    for (final s in [60, 120, 180])
                      ChoiceChip(
                        label: Text('${s ~/ 60}분', style: AppType.label1.copyWith(color: duration == s ? Colors.white : c.labelNeutral)),
                        selected: duration == s,
                        onSelected: (_) => setSheet(() => duration = s),
                        selectedColor: c.accent,
                        backgroundColor: c.bg,
                        shape: RoundedRectangleBorder(borderRadius: AppRadius.b14, side: BorderSide(color: duration == s ? c.accent : c.lineAlt)),
                      ),
                  ]),
                  const SizedBox(height: AppSpace.s16),
                  SectionLabel('재도전 제한'),
                  Wrap(spacing: AppSpace.s8, children: [
                    for (final a in [1, 2, 0])
                      ChoiceChip(
                        label: Text(a == 0 ? '무제한' : '$a회', style: AppType.label1.copyWith(color: maxAttempts == a ? Colors.white : c.labelNeutral)),
                        selected: maxAttempts == a,
                        onSelected: (_) => setSheet(() => maxAttempts = a),
                        selectedColor: c.accent,
                        backgroundColor: c.bg,
                        shape: RoundedRectangleBorder(borderRadius: AppRadius.b14, side: BorderSide(color: maxAttempts == a ? c.accent : c.lineAlt)),
                      ),
                  ]),
                  const SizedBox(height: AppSpace.s20),
                  OclButton(busy ? '만드는 중…' : '만들기', onPressed: busy || picked == null
                      ? null
                      : () async {
                          setSheet(() => busy = true);
                          final questions = await ref.read(worksheetQuestionsProvider(picked!.id).future);
                          final auto = questions.where((q) => q.type.autoGraded).toList();
                          if (auto.isEmpty) {
                            setSheet(() => busy = false);
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('자동 채점 문항이 없어요(서술형 제외).')));
                            }
                            return;
                          }
                          final comp = await ref.read(quizRepositoryProvider).createCompetition(
                                classroomId: classroomId,
                                title: titleCtrl.text.trim().isEmpty ? picked!.title : titleCtrl.text.trim(),
                                questions: auto,
                                durationSec: duration,
                                maxAttempts: maxAttempts,
                              );
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (context.mounted) context.push('/engage/quiz/${comp.id}?t=1', extra: classroomName);
                        }),
                ]),
              ),
            );
          },
        );
      },
    );
  }

  InputDecoration _dec(AppColors c, String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: c.bg,
        enabledBorder: OutlineInputBorder(borderRadius: AppRadius.b14, borderSide: BorderSide(color: c.lineAlt)),
        focusedBorder: OutlineInputBorder(borderRadius: AppRadius.b14, borderSide: BorderSide(color: c.accent, width: 2)),
        contentPadding: const EdgeInsets.all(AppSpace.s16),
      );

  Widget _empty(BuildContext context) {
    final c = context.c;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.emoji_events_outlined, size: 48, color: c.labelAssistive),
          const SizedBox(height: AppSpace.s12),
          Text(teacher ? '아직 만든 대회가 없어요.' : '참가할 대회가 없어요.', style: AppType.body1.copyWith(color: c.labelAlt)),
          if (teacher) ...[
            const SizedBox(height: 4),
            Text('학습지를 골라 대회를 만들어보세요.', style: AppType.body2.copyWith(color: c.labelAssistive)),
          ],
        ]),
      ),
    );
  }
}
