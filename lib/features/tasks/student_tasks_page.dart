import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/task_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/assignment/assignment.dart';
import '../../domain/aiquestion/ai_question_set.dart';
import '../../domain/flashcard/flashcard_deck.dart';
import '../../domain/task/unified_task.dart';
import '../../shared/widgets/ui.dart';
import '../assignments/assignment_format.dart';
import '../student/student_aiquestions.dart' show QuizSolveArgs;
import '../student/student_flashcards.dart' show FlashcardStudyArgs;

/// 학생: "문제" 통합 화면(P2-3) — 숙제·카드 문제·AI 문제를 한 화면에서.
class StudentTasksPage extends ConsumerWidget {
  const StudentTasksPage({super.key});

  static IconData _icon(TaskType t) => switch (t) {
        TaskType.assignment => Icons.assignment_outlined,
        TaskType.card => Icons.style_outlined,
        TaskType.ai => Icons.psychology_outlined,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final tasks = ref.watch(unifiedTasksProvider);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => context.pop()),
        title: Text('문제', style: AppType.headline1),
      ),
      body: SafeArea(
        child: tasks.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.s32),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.checklist_outlined, size: 48, color: c.labelAssistive),
                    const SizedBox(height: AppSpace.s12),
                    Text('받은 문제가 없어요.', style: AppType.body1.copyWith(color: c.labelAlt)),
                  ]),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(AppSpace.s20),
                children: [
                  const SectionLabel('오늘 해야 할 문제'),
                  ...tasks.map((t) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpace.s8),
                        child: _card(context, t),
                      )),
                ],
              ),
      ),
    );
  }

  Widget _card(BuildContext context, UnifiedTask t) {
    final c = context.c;
    return InkWell(
      borderRadius: AppRadius.b16,
      onTap: () => _open(context, t),
      child: OclCard(
        child: Row(children: [
          Icon(_icon(t.type), color: t.completed ? c.labelAssistive : c.accent),
          const SizedBox(width: AppSpace.s12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.title.isEmpty ? '문제' : t.title,
                  style: AppType.headline2.copyWith(color: t.completed ? c.labelAlt : c.labelNormal)),
              const SizedBox(height: 2),
              Row(children: [
                Text(t.type.label, style: AppType.body2.copyWith(color: c.labelAlt)),
                if (t.dueDate != null) ...[
                  const SizedBox(width: AppSpace.s8),
                  Text(dueLabel(t.dueDate, DateTime.now()), style: AppType.body2.copyWith(color: c.labelAlt)),
                ],
              ]),
            ]),
          ),
          if (t.completed)
            Icon(Icons.check_circle, size: 20, color: c.positive)
          else
            Icon(Icons.chevron_right, color: c.labelAssistive),
        ]),
      ),
    );
  }

  void _open(BuildContext context, UnifiedTask t) {
    switch (t.type) {
      case TaskType.assignment:
        context.push('/assignments/detail', extra: t.source as Assignment);
      case TaskType.card:
        context.push('/flashcards/study', extra: FlashcardStudyArgs(t.source as FlashcardDeck, selfEval: false));
      case TaskType.ai:
        context.push('/quizzes/solve', extra: QuizSolveArgs(t.source as AiQuestionSet));
    }
  }
}
