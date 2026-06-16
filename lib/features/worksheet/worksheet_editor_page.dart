import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/worksheet_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/worksheet/worksheet.dart';
import '../../domain/worksheet/worksheet_question.dart';
import '../../shared/widgets/ui.dart';

/// 교사: 학습지 편집(P3-1) — 문항 추가/삭제/순서 변경 + 결과 보기.
class WorksheetEditorPage extends ConsumerWidget {
  final Worksheet worksheet;
  const WorksheetEditorPage({super.key, required this.worksheet});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final questions = ref.watch(worksheetQuestionsProvider(worksheet.id)).valueOrNull ?? const [];

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => context.pop()),
        title: Text(worksheet.title.isEmpty ? '학습지 편집' : worksheet.title, style: AppType.headline1),
        actions: [
          IconButton(
            tooltip: '결과',
            icon: const Icon(Icons.bar_chart_outlined),
            onPressed: () => context.push('/worksheets/results', extra: worksheet),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: c.accent,
        onPressed: () => _openQuestionEditor(context, ref, order: questions.length),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('문항 추가', style: AppType.label1.copyWith(color: Colors.white)),
      ),
      body: SafeArea(
        child: questions.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.s32),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.quiz_outlined, size: 48, color: c.labelAssistive),
                    const SizedBox(height: AppSpace.s12),
                    Text('문항을 추가해보세요.', style: AppType.body1.copyWith(color: c.labelAlt)),
                  ]),
                ),
              )
            : ReorderableListView.builder(
                padding: const EdgeInsets.all(AppSpace.s20),
                itemCount: questions.length,
                onReorder: (oldI, newI) => _reorder(ref, questions, oldI, newI),
                itemBuilder: (context, i) {
                  final q = questions[i];
                  return Padding(
                    key: ValueKey(q.id),
                    padding: const EdgeInsets.only(bottom: AppSpace.s8),
                    child: OclCard(
                      child: Row(children: [
                        Text('${i + 1}', style: AppType.headline2.copyWith(color: c.accent)),
                        const SizedBox(width: AppSpace.s12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(q.question.isEmpty ? '(빈 문항)' : q.question, style: AppType.body1.copyWith(color: c.labelNormal)),
                            const SizedBox(height: 2),
                            Text(q.type.label, style: AppType.caption1.copyWith(color: c.labelAlt)),
                          ]),
                        ),
                        IconButton(
                          icon: Icon(Icons.edit_outlined, size: 18, color: c.labelAssistive),
                          onPressed: () => _openQuestionEditor(context, ref, existing: q, order: q.order),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, size: 18, color: c.labelAssistive),
                          onPressed: () => ref.read(worksheetRepositoryProvider).deleteQuestion(q.id),
                        ),
                        ReorderableDragStartListener(index: i, child: Icon(Icons.drag_handle, color: c.labelAssistive)),
                      ]),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _reorder(WidgetRef ref, List<WorksheetQuestion> qs, int oldI, int newI) async {
    final list = [...qs];
    if (newI > oldI) newI--;
    final moved = list.removeAt(oldI);
    list.insert(newI, moved);
    final repo = ref.read(worksheetRepositoryProvider);
    for (var i = 0; i < list.length; i++) {
      if (list[i].order != i) {
        await repo.updateQuestion(WorksheetQuestion(
          id: list[i].id,
          worksheetId: list[i].worksheetId,
          teacherUid: list[i].teacherUid,
          type: list[i].type,
          question: list[i].question,
          choices: list[i].choices,
          answer: list[i].answer,
          order: i,
        ));
      }
    }
  }

  void _openQuestionEditor(BuildContext context, WidgetRef ref, {WorksheetQuestion? existing, required int order}) {
    var type = existing?.type ?? WorksheetQuestionType.multipleChoice;
    final qCtrl = TextEditingController(text: existing?.question ?? '');
    final choicesCtrl = TextEditingController(text: existing?.choices.join('\n') ?? '');
    final answerCtrl = TextEditingController(text: existing?.answer ?? '');
    var busy = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.c.bgElevated,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: AppRadius.r24)),
      builder: (sheetCtx) {
        final c = sheetCtx.c;
        return StatefulBuilder(
          builder: (ctx, setSheet) => Padding(
            padding: EdgeInsets.fromLTRB(
                AppSpace.s20, AppSpace.s20, AppSpace.s20, MediaQuery.of(ctx).viewInsets.bottom + AppSpace.s24),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(existing == null ? '문항 추가' : '문항 수정', style: AppType.title3),
                const SizedBox(height: AppSpace.s16),
                Wrap(
                  spacing: AppSpace.s8,
                  children: WorksheetQuestionType.values
                      .map((t) => ChoiceChip(label: Text(t.label), selected: type == t, onSelected: (_) => setSheet(() => type = t)))
                      .toList(),
                ),
                const SizedBox(height: AppSpace.s12),
                TextField(controller: qCtrl, maxLines: 2, style: AppType.body1.copyWith(color: c.labelNormal), decoration: _dec(c, '질문')),
                if (type == WorksheetQuestionType.multipleChoice) ...[
                  const SizedBox(height: AppSpace.s12),
                  TextField(controller: choicesCtrl, maxLines: 4, style: AppType.body1.copyWith(color: c.labelNormal), decoration: _dec(c, '보기 (한 줄에 하나)')),
                ],
                const SizedBox(height: AppSpace.s12),
                if (type == WorksheetQuestionType.ox)
                  Row(children: [
                    Expanded(child: _oxBtn(c, answerCtrl, 'O', setSheet)),
                    const SizedBox(width: AppSpace.s8),
                    Expanded(child: _oxBtn(c, answerCtrl, 'X', setSheet)),
                  ])
                else if (type != WorksheetQuestionType.essay)
                  TextField(controller: answerCtrl, style: AppType.body1.copyWith(color: c.labelNormal), decoration: _dec(c, '정답')),
                if (type == WorksheetQuestionType.essay)
                  Text('서술형은 자동 채점에서 제외돼요.', style: AppType.body2.copyWith(color: c.labelAlt)),
                const SizedBox(height: AppSpace.s20),
                OclButton(busy ? '저장 중…' : '저장', onPressed: busy
                    ? null
                    : () async {
                        final question = qCtrl.text.trim();
                        if (question.isEmpty) return;
                        setSheet(() => busy = true);
                        final repo = ref.read(worksheetRepositoryProvider);
                        final choices = type == WorksheetQuestionType.multipleChoice
                            ? choicesCtrl.text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
                            : <String>[];
                        if (existing == null) {
                          await repo.createQuestion(
                              worksheetId: worksheet.id, type: type, question: question, choices: choices, answer: answerCtrl.text.trim(), order: order);
                        } else {
                          await repo.updateQuestion(WorksheetQuestion(
                            id: existing.id,
                            worksheetId: worksheet.id,
                            teacherUid: existing.teacherUid,
                            type: type,
                            question: question,
                            choices: choices,
                            answer: answerCtrl.text.trim(),
                            order: existing.order,
                          ));
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                      }),
              ]),
            ),
          ),
        );
      },
    );
  }

  Widget _oxBtn(AppColors c, TextEditingController answerCtrl, String v, void Function(void Function()) setSheet) {
    final selected = answerCtrl.text == v;
    return SizedBox(
      height: 52,
      child: Material(
        color: selected ? c.accent : c.fill,
        borderRadius: AppRadius.b14,
        child: InkWell(
          borderRadius: AppRadius.b14,
          onTap: () => setSheet(() => answerCtrl.text = v),
          child: Center(child: Text(v, style: AppType.title3.copyWith(color: selected ? Colors.white : c.labelNeutral))),
        ),
      ),
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
}
