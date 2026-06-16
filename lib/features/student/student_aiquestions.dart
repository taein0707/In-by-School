import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/account_providers.dart';
import '../../app/aiquestion_providers.dart';
import '../../app/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/aiquestion/ai_question_set.dart';
import '../../domain/growth/growth.dart';
import '../../shared/widgets/ui.dart';

PreferredSizeWidget _bar(BuildContext context, String title, {bool back = false}) {
  final c = context.c;
  return AppBar(
    backgroundColor: c.bg,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    centerTitle: false,
    titleSpacing: back ? 0 : AppSpace.s20,
    leading: back ? IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => context.pop()) : null,
    title: Text(title, style: AppType.headline1),
  );
}

/// 풀이/결과 화면 인자.
class QuizSolveArgs {
  final AiQuestionSet set;
  const QuizSolveArgs(this.set);
}

class QuizResultArgs {
  final AiQuestionResult result;
  final List<AiQuestion> questions;
  const QuizResultArgs(this.result, this.questions);
}

/// 학생 · AI 문제 탭 — 새 문제 / 완료.
class StudentAiQuestionsPage extends ConsumerWidget {
  const StudentAiQuestionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final async = ref.watch(studentQuestionSetsProvider);
    final results = ref.watch(myQuestionResultsProvider).value ?? const <String, AiQuestionResult>{};

    return Scaffold(
      appBar: _bar(context, 'AI 문제'),
      body: SafeArea(
        top: false,
        child: async.when(
          loading: () => Center(child: CircularProgressIndicator(color: c.accent)),
          error: (e, _) => Center(child: Text('불러오지 못했어요.', style: AppType.body2.copyWith(color: c.labelAlt))),
          data: (list) => list.isEmpty ? _empty(context) : _grouped(context, list, results),
        ),
      ),
    );
  }

  Widget _empty(BuildContext context) {
    final c = context.c;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.smart_toy_outlined, size: 48, color: c.labelAssistive),
            const SizedBox(height: AppSpace.s12),
            Text('받은 문제가 없어요.', style: AppType.body1.copyWith(color: c.labelAlt)),
          ],
        ),
      ),
    );
  }

  Widget _grouped(BuildContext context, List<AiQuestionSet> list, Map<String, AiQuestionResult> results) {
    final fresh = <AiQuestionSet>[];
    final done = <AiQuestionSet>[];
    for (final s in list) {
      (results[s.id]?.isDone ?? false) ? done.add(s) : fresh.add(s);
    }

    Widget section(String label, List<AiQuestionSet> sets) {
      if (sets.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(label),
          ...sets.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.s8),
              child: _SetRow(set: s, result: results[s.id]))),
          const SizedBox(height: AppSpace.s12),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpace.s20),
      children: [section('새 문제', fresh), section('완료', done)],
    );
  }
}

class _SetRow extends StatelessWidget {
  final AiQuestionSet set;
  final AiQuestionResult? result;
  const _SetRow({required this.set, this.result});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final done = result?.isDone ?? false;
    return InkWell(
      borderRadius: AppRadius.b16,
      onTap: () => context.push('/quizzes/solve', extra: QuizSolveArgs(set)),
      child: OclCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(set.title, style: AppType.headline2)),
                if (done)
                  Text('${result!.correctPercent}%',
                      style: AppType.headline2.copyWith(color: c.accent, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              [
                if (set.teacherName.isNotEmpty) '${set.teacherName} 선생님',
                '문제 ${set.questionCount}개',
                set.difficulty.label,
              ].join(' · '),
              style: AppType.body2.copyWith(color: c.labelAlt),
            ),
          ],
        ),
      ),
    );
  }
}

/// 학생 · 문제 풀이(전체 스크롤 폼) → 제출 시 자동 채점.
class StudentQuizSolvePage extends ConsumerStatefulWidget {
  final QuizSolveArgs args;
  const StudentQuizSolvePage({super.key, required this.args});
  @override
  ConsumerState<StudentQuizSolvePage> createState() => _SolveState();
}

class _SolveState extends ConsumerState<StudentQuizSolvePage> {
  List<AiQuestion>? _questions;
  final Map<int, String> _given = {}; // index → 응답
  final Map<int, TextEditingController> _text = {};
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final t in _text.values) {
      t.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    // 학생용 메서드(studentUids 필터)로 규칙 충족. 실패해도 빈 목록으로 degrade(스피너 멈춤 방지).
    List<AiQuestion> qs;
    try {
      qs = await ref.read(aiQuestionRepositoryProvider).fetchQuestionsForStudent(widget.args.set.id);
    } catch (_) {
      qs = const [];
    }
    if (!mounted) return;
    setState(() => _questions = qs);
  }

  TextEditingController _ctrl(int i) => _text.putIfAbsent(i, () => TextEditingController());

  Future<void> _submit(List<AiQuestion> qs) async {
    // 텍스트형 응답 수집
    for (var i = 0; i < qs.length; i++) {
      if (qs[i].type != QuestionType.multipleChoice) {
        _given[i] = _ctrl(i).text.trim();
      }
    }
    final unanswered = List.generate(qs.length, (i) => i).where((i) => (_given[i] ?? '').isEmpty).length;
    if (unanswered > 0) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('제출할까요?'),
          content: Text('아직 답하지 않은 문제가 $unanswered개 있어요.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('계속 풀기')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('제출')),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() => _submitting = true);
    try {
      final givens = List.generate(qs.length, (i) => _given[i] ?? '');
      final result = await ref.read(aiQuestionRepositoryProvider).submitAnswers(
            set: widget.args.set,
            questions: qs,
            givens: givens,
            studentName: ref.read(currentProfileProvider).value?.displayName ?? '',
          );
      // 풀이 완료 보상 — 정답 수 기반(기본 + 정답당 5XP). Life 와 무관.
      ref.read(appProvider.notifier).awardXp(
            XpSource.aiQuiz,
            XpSource.aiQuiz.defaultXp + result.correctCount * 5,
          );
      if (!mounted) return;
      context.pushReplacement('/quizzes/result', extra: QuizResultArgs(result, qs));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final qs = _questions;
    if (qs == null) {
      return Scaffold(appBar: _bar(context, widget.args.set.title, back: true), body: Center(child: CircularProgressIndicator(color: c.accent)));
    }
    if (qs.isEmpty) {
      return Scaffold(
        appBar: _bar(context, widget.args.set.title, back: true),
        body: Center(child: Text('이 세트에는 문제가 없어요.', style: AppType.body1.copyWith(color: c.labelAlt))),
      );
    }
    return Scaffold(
      appBar: _bar(context, widget.args.set.title, back: true),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpace.s20),
          children: [
            ...List.generate(qs.length, (i) => _questionCard(c, i, qs[i])),
            const SizedBox(height: AppSpace.s12),
            _submitting
                ? Center(child: CircularProgressIndicator(color: c.accent))
                : OclButton('제출하고 채점하기', onPressed: () => _submit(qs)),
            const SizedBox(height: AppSpace.s24),
          ],
        ),
      ),
    );
  }

  Widget _questionCard(AppColors c, int i, AiQuestion q) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s12),
      child: OclCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text('${i + 1}', style: AppType.headline2.copyWith(color: c.accent)),
              const SizedBox(width: AppSpace.s8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: c.fill, borderRadius: AppRadius.bFull),
                child: Text(q.type.label, style: AppType.caption1.copyWith(color: c.labelAlt)),
              ),
            ]),
            const SizedBox(height: AppSpace.s8),
            Text(q.prompt, style: AppType.body1.copyWith(color: c.labelNormal)),
            const SizedBox(height: AppSpace.s12),
            if (q.type == QuestionType.multipleChoice)
              ...q.choices.map((choice) => _choiceTile(c, i, choice))
            else
              TextField(
                controller: _ctrl(i),
                style: AppType.body1.copyWith(color: c.labelNormal),
                decoration: InputDecoration(
                  hintText: q.type == QuestionType.fillBlank ? '빈칸에 들어갈 말' : '정답 입력',
                  filled: true,
                  fillColor: c.bgElevated,
                  enabledBorder: OutlineInputBorder(borderRadius: AppRadius.b14, borderSide: BorderSide(color: c.lineAlt)),
                  focusedBorder: OutlineInputBorder(borderRadius: AppRadius.b14, borderSide: BorderSide(color: c.accent, width: 2)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.s16, vertical: AppSpace.s14),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _choiceTile(AppColors c, int i, String choice) {
    final on = _given[i] == choice;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s8),
      child: InkWell(
        borderRadius: AppRadius.b14,
        onTap: () => setState(() => _given[i] = choice),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16, vertical: AppSpace.s12),
          decoration: BoxDecoration(
            color: on ? c.accentSoft : c.bgElevated,
            borderRadius: AppRadius.b14,
            border: Border.all(color: on ? c.accent : c.lineAlt),
          ),
          child: Row(
            children: [
              Icon(on ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  size: 20, color: on ? c.accent : c.labelAssistive),
              const SizedBox(width: AppSpace.s12),
              Expanded(child: Text(choice, style: AppType.body1)),
            ],
          ),
        ),
      ),
    );
  }
}

/// 학생 · 채점 결과(점수 + 문제별 정오·해설).
class StudentQuizResultPage extends StatelessWidget {
  final QuizResultArgs args;
  const StudentQuizResultPage({super.key, required this.args});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final r = args.result;
    final qs = args.questions;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpace.s24),
                children: [
                  Text('채점 결과', style: AppType.title2),
                  const SizedBox(height: AppSpace.s16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpace.s20),
                    decoration: BoxDecoration(color: c.accentSoft, borderRadius: AppRadius.b16),
                    child: Column(children: [
                      Text('${r.correctCount} / ${r.total}',
                          style: AppType.display3.copyWith(color: c.accent, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text('정답률 ${r.correctPercent}%', style: AppType.body1.copyWith(color: c.labelNeutral)),
                    ]),
                  ),
                  const SizedBox(height: AppSpace.s20),
                  const SectionLabel('문제별 풀이'),
                  ...List.generate(qs.length, (i) => _review(context, i, qs[i],
                      i < r.responses.length ? r.responses[i] : const QuestionResponse(given: '', correct: false))),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.s24, 0, AppSpace.s24, AppSpace.s12),
              child: OclButton('확인', onPressed: () => context.go('/quizzes')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _review(BuildContext context, int i, AiQuestion q, QuestionResponse resp) {
    final c = context.c;
    final ok = resp.correct;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s8),
      child: OclCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(ok ? Icons.check_circle : Icons.cancel,
                  size: 18, color: ok ? c.positive : c.negative),
              const SizedBox(width: 6),
              Expanded(child: Text('${i + 1}. ${q.prompt}', style: AppType.body1.copyWith(color: c.labelNormal))),
            ]),
            const SizedBox(height: 6),
            Text('내 답: ${resp.given.isEmpty ? '(미응답)' : resp.given}',
                style: AppType.body2.copyWith(color: ok ? c.labelAlt : c.negative)),
            if (!ok) Text('정답: ${q.answer}', style: AppType.body2.copyWith(color: c.accent)),
            if (q.explanation.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(q.explanation, style: AppType.caption1.copyWith(color: c.labelAlt)),
            ],
          ],
        ),
      ),
    );
  }
}
