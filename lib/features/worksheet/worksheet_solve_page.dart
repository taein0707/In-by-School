import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/account_providers.dart';
import '../../app/worksheet_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/worksheet/worksheet.dart';
import '../../domain/worksheet/worksheet_question.dart';
import '../../features/brand/submit_celebration.dart';
import '../../shared/widgets/ui.dart';

/// 학생: 학습지 풀이(P3-1) — 설문 스타일, 한 문제씩 슬라이드 + 자동 채점 제출.
class WorksheetSolvePage extends ConsumerStatefulWidget {
  final Worksheet worksheet;
  const WorksheetSolvePage({super.key, required this.worksheet});
  @override
  ConsumerState<WorksheetSolvePage> createState() => _WorksheetSolvePageState();
}

class _WorksheetSolvePageState extends ConsumerState<WorksheetSolvePage> {
  int _i = 0;
  bool _submitting = false;
  final Map<String, String> _answers = {}; // questionId → 답
  final Map<String, TextEditingController> _text = {};

  @override
  void dispose() {
    for (final t in _text.values) {
      t.dispose();
    }
    super.dispose();
  }

  TextEditingController _ctrl(String id) => _text.putIfAbsent(id, () => TextEditingController(text: _answers[id] ?? ''));

  Future<void> _submit(List<WorksheetQuestion> qs) async {
    // 텍스트형(단답/서술) 답 수집
    for (final q in qs) {
      if (q.type == WorksheetQuestionType.shortAnswer || q.type == WorksheetQuestionType.essay) {
        _answers[q.id] = _ctrl(q.id).text.trim();
      }
    }
    setState(() => _submitting = true);
    final result = WorksheetGrading.grade(qs, _answers);
    final name = ref.read(currentProfileProvider).valueOrNull?.displayName ?? '';
    await ref.read(worksheetRepositoryProvider).submitWorksheet(
          worksheet: widget.worksheet,
          studentName: name,
          answers: _answers,
          score: result.score,
          total: result.total,
        );
    if (!mounted) return;
    // 제출 완료 브랜드 셀러브레이션 — 자동 채점 점수를 함께 보여준다.
    // (토리/연속 학습은 실제 보상이 연동될 때 chip 으로 노출.)
    await SubmitCelebration.show(
      context,
      subtitle: '자동 채점 ${result.score} / ${result.total}\n(서술형은 채점에서 제외돼요)',
    );
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final qs = ref.watch(worksheetQuestionsProvider(widget.worksheet.id)).valueOrNull ?? const [];

    if (qs.isEmpty) {
      return Scaffold(
        backgroundColor: c.bg,
        appBar: _bar(context, widget.worksheet.title),
        body: Center(child: Text('아직 문항이 없어요.', style: AppType.body1.copyWith(color: c.labelAlt))),
      );
    }
    final idx = _i.clamp(0, qs.length - 1);
    final q = qs[idx];
    final isLast = idx == qs.length - 1;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: _bar(context, widget.worksheet.title),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: AppRadius.bFull,
                child: LinearProgressIndicator(
                  value: (idx + 1) / qs.length,
                  minHeight: 6,
                  backgroundColor: c.fillStrong,
                  valueColor: AlwaysStoppedAnimation(c.accent),
                ),
              ),
              const SizedBox(height: AppSpace.s12),
              Text('문제 ${idx + 1} / ${qs.length}', style: AppType.label1.copyWith(color: c.labelAlt)),
              const SizedBox(height: AppSpace.s16),
              Text(q.question, style: AppType.title3.copyWith(color: c.labelNormal)),
              const SizedBox(height: AppSpace.s20),
              Expanded(child: SingleChildScrollView(child: _input(c, q))),
              Row(children: [
                if (idx > 0)
                  Expanded(child: OclButton('이전', ghost: true, onPressed: () => setState(() => _i = idx - 1))),
                if (idx > 0) const SizedBox(width: AppSpace.s10),
                Expanded(
                  child: isLast
                      ? OclButton(_submitting ? '제출 중…' : '제출하기', onPressed: _submitting ? null : () => _submit(qs))
                      : OclButton('다음', onPressed: () => setState(() => _i = idx + 1)),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _input(AppColors c, WorksheetQuestion q) {
    switch (q.type) {
      case WorksheetQuestionType.multipleChoice:
        return Column(
          children: q.choices
              .map((opt) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.s8),
                    child: _choice(c, q.id, opt),
                  ))
              .toList(),
        );
      case WorksheetQuestionType.ox:
        return Row(children: [
          Expanded(child: _choice(c, q.id, 'O', big: true)),
          const SizedBox(width: AppSpace.s10),
          Expanded(child: _choice(c, q.id, 'X', big: true)),
        ]);
      case WorksheetQuestionType.shortAnswer:
      case WorksheetQuestionType.essay:
        return TextField(
          controller: _ctrl(q.id),
          maxLines: q.type == WorksheetQuestionType.essay ? 6 : 1,
          style: AppType.body1.copyWith(color: c.labelNormal),
          decoration: InputDecoration(
            hintText: q.type == WorksheetQuestionType.essay ? '서술형 답안' : '정답 입력',
            filled: true,
            fillColor: c.bgElevated,
            enabledBorder: OutlineInputBorder(borderRadius: AppRadius.b14, borderSide: BorderSide(color: c.lineAlt)),
            focusedBorder: OutlineInputBorder(borderRadius: AppRadius.b14, borderSide: BorderSide(color: c.accent, width: 2)),
            contentPadding: const EdgeInsets.all(AppSpace.s16),
          ),
        );
    }
  }

  Widget _choice(AppColors c, String qid, String opt, {bool big = false}) {
    final selected = _answers[qid] == opt;
    return Material(
      color: selected ? c.accentSoft : c.bgElevated,
      borderRadius: AppRadius.b14,
      child: InkWell(
        borderRadius: AppRadius.b14,
        onTap: () => setState(() => _answers[qid] = opt),
        child: Container(
          height: big ? 64 : null,
          width: double.infinity,
          alignment: big ? Alignment.center : Alignment.centerLeft,
          padding: const EdgeInsets.all(AppSpace.s16),
          decoration: BoxDecoration(
            borderRadius: AppRadius.b14,
            border: Border.all(color: selected ? c.accent : c.lineAlt, width: selected ? 2 : 1),
          ),
          child: Text(opt, style: (big ? AppType.title2 : AppType.body1).copyWith(color: c.labelNormal)),
        ),
      ),
    );
  }

  PreferredSizeWidget _bar(BuildContext context, String title) => AppBar(
        backgroundColor: context.c.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(title.isEmpty ? '학습지' : title, style: AppType.headline2),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => context.pop()),
      );
}
