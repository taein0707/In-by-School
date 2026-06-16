import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/worksheet_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/worksheet/worksheet.dart';
import '../../domain/worksheet/worksheet_question.dart';
import '../../domain/worksheet/worksheet_submission.dart';
import '../../shared/widgets/ui.dart';

/// 교사: 학습지 결과(P3-1) — 제출자 목록(점수) + 학생별 답안 확인.
class WorksheetResultsPage extends ConsumerWidget {
  final Worksheet worksheet;
  const WorksheetResultsPage({super.key, required this.worksheet});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final subs = ref.watch(worksheetSubmissionsProvider(worksheet.id)).valueOrNull ?? const [];
    final questions = ref.watch(worksheetQuestionsProvider(worksheet.id)).valueOrNull ?? const [];

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => context.pop()),
        title: Text('${worksheet.title} · 결과', style: AppType.headline1),
      ),
      body: SafeArea(
        child: subs.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.s32),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.bar_chart_outlined, size: 48, color: c.labelAssistive),
                    const SizedBox(height: AppSpace.s12),
                    Text('아직 제출이 없어요.', style: AppType.body1.copyWith(color: c.labelAlt)),
                  ]),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(AppSpace.s20),
                children: subs
                    .map((s) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpace.s8),
                          child: InkWell(
                            borderRadius: AppRadius.b16,
                            onTap: () => _showAnswers(context, s, questions),
                            child: OclCard(
                              child: Row(children: [
                                CircleAvatar(radius: 18, backgroundColor: c.accentSoft, child: Icon(Icons.person, size: 18, color: c.accent)),
                                const SizedBox(width: AppSpace.s12),
                                Expanded(child: Text(s.studentName.isEmpty ? '학생' : s.studentName, style: AppType.body1.copyWith(color: c.labelNormal))),
                                Text('${s.score} / ${s.total}', style: AppType.headline2.copyWith(color: c.accent)),
                              ]),
                            ),
                          ),
                        ))
                    .toList(),
              ),
      ),
    );
  }

  void _showAnswers(BuildContext context, WorksheetSubmission s, List<WorksheetQuestion> questions) {
    final c = context.c;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.bgElevated,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: AppRadius.r24)),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('${s.studentName.isEmpty ? '학생' : s.studentName} · ${s.score}/${s.total}', style: AppType.title3),
            const SizedBox(height: AppSpace.s16),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: questions.map((q) {
                  final given = s.answers[q.id] ?? '';
                  final graded = q.type.autoGraded;
                  final correct = graded && q.isCorrect(given);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.s12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        if (graded)
                          Icon(correct ? Icons.check_circle : Icons.cancel, size: 16, color: correct ? c.positive : c.negative)
                        else
                          Icon(Icons.edit_note, size: 16, color: c.labelAssistive),
                        const SizedBox(width: 6),
                        Expanded(child: Text(q.question, style: AppType.body2.copyWith(color: c.labelNeutral))),
                      ]),
                      const SizedBox(height: 2),
                      Text('답: ${given.isEmpty ? '(무응답)' : given}', style: AppType.body2.copyWith(color: c.labelAlt)),
                      if (graded && !correct) Text('정답: ${q.answer}', style: AppType.caption1.copyWith(color: c.positive)),
                    ]),
                  );
                }).toList(),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
