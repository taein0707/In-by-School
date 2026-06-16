import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/account_providers.dart';
import '../../app/aiquestion_providers.dart';
import '../../app/classroom_providers.dart';
import '../../app/flashcard_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/ai/gemini_service.dart';
import '../../domain/aiquestion/ai_question_set.dart';
import '../../domain/classroom/classroom.dart';
import '../../domain/assignment/assignment.dart' show Difficulty;
import '../../domain/flashcard/flashcard_deck.dart';
import '../../shared/widgets/ui.dart';

PreferredSizeWidget _bar(BuildContext context, String title, {List<Widget>? actions, bool back = false}) {
  final c = context.c;
  return AppBar(
    backgroundColor: c.bg,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    centerTitle: false,
    titleSpacing: back ? 0 : AppSpace.s20,
    leading: back ? IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => context.pop()) : null,
    title: Text(title, style: AppType.headline1),
    actions: actions,
  );
}

InputDecoration _dec(AppColors c, String hint) => InputDecoration(
      hintText: hint,
      isDense: true,
      filled: true,
      fillColor: c.bgElevated,
      enabledBorder: OutlineInputBorder(borderRadius: AppRadius.b14, borderSide: BorderSide(color: c.lineAlt)),
      focusedBorder: OutlineInputBorder(borderRadius: AppRadius.b14, borderSide: BorderSide(color: c.accent, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.s16, vertical: AppSpace.s14),
    );

Widget _chip(BuildContext context, String label, bool on, VoidCallback onTap) {
  final c = context.c;
  return InkWell(
    borderRadius: AppRadius.bFull,
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16, vertical: AppSpace.s8),
      decoration: BoxDecoration(
        color: on ? c.accentSoft : c.fill,
        borderRadius: AppRadius.bFull,
        border: Border.all(color: on ? c.accent : Colors.transparent),
      ),
      child: Text(label, style: AppType.label1.copyWith(color: on ? c.accent : c.labelNeutral)),
    ),
  );
}

/// 선생님 · AI 문제 세트 목록 (탭).
class TeacherAiQuestionsPage extends ConsumerWidget {
  const TeacherAiQuestionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final async = ref.watch(teacherQuestionSetsProvider);
    return Scaffold(
      appBar: _bar(context, 'AI 문제'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/t/ai/new'),
        backgroundColor: c.accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('문제 만들기'),
      ),
      body: SafeArea(
        top: false,
        child: async.when(
          loading: () => Center(child: CircularProgressIndicator(color: c.accent)),
          error: (e, _) => Center(child: Text('불러오지 못했어요.', style: AppType.body2.copyWith(color: c.labelAlt))),
          data: (list) => list.isEmpty
              ? _empty(context)
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpace.s20),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpace.s8),
                  itemBuilder: (_, i) => _SetRow(set: list[i]),
                ),
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
            Text('아직 만든 문제가 없어요.\n주제를 입력하거나 카드 덱을 골라 AI로 만들어 보세요.',
                textAlign: TextAlign.center, style: AppType.body1.copyWith(color: c.labelAlt)),
          ],
        ),
      ),
    );
  }
}

class _SetRow extends ConsumerWidget {
  final AiQuestionSet set;
  const _SetRow({required this.set});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final results = ref.watch(resultsForSetProvider(set.id)).value ?? const {};
    final total = set.studentUids.length;
    final done = set.studentUids.where((u) => results[u]?.isDone ?? false).length;
    final allDone = total > 0 && done == total;

    return InkWell(
      borderRadius: AppRadius.b16,
      onTap: () => context.push('/t/ai/detail', extra: set),
      child: OclCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(set.title, style: AppType.headline2)),
                if (set.fromDeck)
                  Icon(Icons.style_outlined, size: 16, color: c.labelAssistive),
                if (set.fallbackUsed)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Icon(Icons.cloud_off_outlined, size: 16, color: c.cautionary),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    ['문제 ${set.questionCount}개', set.difficulty.label, '학생 $total명'].join(' · '),
                    style: AppType.body2.copyWith(color: c.labelAlt),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.s8, vertical: 3),
                  decoration: BoxDecoration(color: allDone ? c.accentSoft : c.fill, borderRadius: AppRadius.bFull),
                  child: Text('완료 $done/$total',
                      style: AppType.caption1.copyWith(color: allDone ? c.accent : c.labelNeutral)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 문제 1개 작성용 임시 모델(자체 컨트롤러).
class _QDraft {
  QuestionType type;
  final TextEditingController prompt;
  final TextEditingController answer;
  final TextEditingController explanation;
  final TextEditingController choices; // 한 줄에 하나(객관식)

  _QDraft({
    required this.type,
    String prompt = '',
    String answer = '',
    String explanation = '',
    List<String> choices = const [],
  })  : prompt = TextEditingController(text: prompt),
        answer = TextEditingController(text: answer),
        explanation = TextEditingController(text: explanation),
        choices = TextEditingController(text: choices.join('\n'));

  factory _QDraft.from(AiQuestion q) => _QDraft(
        type: q.type,
        prompt: q.prompt,
        answer: q.answer,
        explanation: q.explanation,
        choices: q.choices,
      );

  bool get isValid => prompt.text.trim().isNotEmpty && answer.text.trim().isNotEmpty;

  AiQuestion toQuestion() => AiQuestion(
        type: type,
        prompt: prompt.text.trim(),
        answer: answer.text.trim(),
        explanation: explanation.text.trim(),
        choices: type == QuestionType.multipleChoice
            ? choices.text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
            : const [],
      );

  void dispose() {
    prompt.dispose();
    answer.dispose();
    explanation.dispose();
    choices.dispose();
  }
}

/// 선생님 · 문제 세트 생성(독립 주제 + 플래시카드 연계).
class TeacherQuestionCreatePage extends ConsumerStatefulWidget {
  const TeacherQuestionCreatePage({super.key});
  @override
  ConsumerState<TeacherQuestionCreatePage> createState() => _CreateState();
}

class _CreateState extends ConsumerState<TeacherQuestionCreatePage> {
  final _title = TextEditingController();
  final _topic = TextEditingController();
  Difficulty _difficulty = Difficulty.medium;
  int _count = 5;
  final Set<QuestionType> _types = {QuestionType.multipleChoice};
  String? _deckId; // null=주제만
  final List<_QDraft> _drafts = [];
  final Set<String> _selected = {};
  QuestionGenResult? _gen;
  bool _generating = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _topic.dispose();
    for (final d in _drafts) {
      d.dispose();
    }
    super.dispose();
  }

  Future<void> _generate() async {
    if (_types.isEmpty) return setState(() => _error = '문제 유형을 한 개 이상 선택해주세요.');
    if (_deckId == null && _topic.text.trim().isEmpty) {
      return setState(() => _error = '주제를 입력하거나 카드 덱을 선택해주세요.');
    }
    setState(() {
      _generating = true;
      _error = null;
    });
    try {
      var cards = <QuestionCard>[];
      if (_deckId != null) {
        final list = await ref.read(flashcardRepositoryProvider).fetchCardsForTeacher(_deckId!);
        cards = list.map((c) => QuestionCard(front: c.front, back: c.back, example: c.example)).toList();
      }
      final topic = _topic.text.trim().isEmpty ? (_deckTitle() ?? '학습') : _topic.text.trim();
      final gen = await GeminiService.generateQuestions(
        topic: topic,
        difficulty: _difficulty,
        count: _count,
        types: _types,
        cards: cards,
      );
      setState(() {
        for (final d in _drafts) {
          d.dispose();
        }
        _drafts
          ..clear()
          ..addAll(gen.questions.map(_QDraft.from));
        _gen = gen;
      });
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  String? _deckTitle() {
    final decks = ref.read(teacherDecksProvider).value ?? const [];
    for (final d in decks) {
      if (d.id == _deckId) return d.title;
    }
    return null;
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) return setState(() => _error = '제목을 입력해주세요.');
    final questions = _drafts.where((d) => d.isValid).map((d) => d.toQuestion()).toList();
    if (questions.isEmpty) return setState(() => _error = '지문과 정답이 채워진 문제가 한 개 이상 필요해요.');
    if (_selected.isEmpty) return setState(() => _error = '배포할 학생을 한 명 이상 선택해주세요.');
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final profile = ref.read(currentProfileProvider).value;
      await ref.read(aiQuestionRepositoryProvider).createSet(
            teacherName: profile?.displayName ?? '',
            title: _title.text.trim(),
            topic: _topic.text.trim().isEmpty ? (_deckTitle() ?? '') : _topic.text.trim(),
            difficulty: _difficulty,
            questions: questions,
            studentUids: _selected.toList(),
            sourceDeckId: _deckId,
            gen: _gen ??
                const QuestionGenResult(
                    questions: [], fallbackUsed: false, model: '', promptTokens: 0, candidatesTokens: 0, totalTokens: 0),
          );
      if (mounted) context.pop();
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final decks = ref.watch(teacherDecksProvider).value ?? const <FlashcardDeck>[];
    final students = ref.watch(teacherStudentsProvider).value ?? const <ClassroomMember>[];
    final validCount = _drafts.where((d) => d.isValid).length;

    return Scaffold(
      appBar: _bar(context, '문제 만들기', back: true),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpace.s24),
          children: [
            TextField(controller: _title, style: AppType.body1.copyWith(color: c.labelNormal), decoration: _dec(c, '제목 (예: 1단원 형성평가)')),
            const SizedBox(height: AppSpace.s10),
            TextField(controller: _topic, style: AppType.body1.copyWith(color: c.labelNormal), decoration: _dec(c, '주제/단원 (예: 광합성)')),
            const SizedBox(height: AppSpace.s20),

            // ---- 출처: 주제 / 카드 덱 ----
            const SectionLabel('출처'),
            Wrap(spacing: AppSpace.s8, runSpacing: AppSpace.s8, children: [
              _chip(context, '주제만', _deckId == null, () => setState(() => _deckId = null)),
              ...decks.map((d) => _chip(context, d.title, _deckId == d.id, () => setState(() => _deckId = d.id))),
            ]),
            if (decks.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('카드 덱이 없으면 주제만으로 생성돼요.', style: AppType.caption1.copyWith(color: c.labelAlt)),
              ),
            const SizedBox(height: AppSpace.s20),

            // ---- 난이도 ----
            const SectionLabel('난이도'),
            Wrap(spacing: AppSpace.s8, children: Difficulty.values
                .map((d) => _chip(context, d.label, _difficulty == d, () => setState(() => _difficulty = d)))
                .toList()),
            const SizedBox(height: AppSpace.s20),

            // ---- 문제 수 ----
            const SectionLabel('문제 수'),
            Wrap(spacing: AppSpace.s8, children: [3, 5, 10]
                .map((n) => _chip(context, '$n개', _count == n, () => setState(() => _count = n)))
                .toList()),
            const SizedBox(height: AppSpace.s20),

            // ---- 유형(복수) ----
            const SectionLabel('문제 유형'),
            Wrap(spacing: AppSpace.s8, runSpacing: AppSpace.s8, children: QuestionType.values
                .map((t) => _chip(context, t.label, _types.contains(t), () => setState(() {
                      _types.contains(t) ? _types.remove(t) : _types.add(t);
                    })))
                .toList()),
            const SizedBox(height: AppSpace.s16),

            _generating
                ? Center(child: Padding(
                    padding: const EdgeInsets.all(AppSpace.s12),
                    child: Column(children: [
                      CircularProgressIndicator(color: c.accent),
                      const SizedBox(height: AppSpace.s8),
                      Text('AI가 문제를 만들고 있어요…', style: AppType.body2.copyWith(color: c.labelAlt)),
                    ]),
                  ))
                : OclButton(_drafts.isEmpty ? 'AI로 문제 생성' : '문제 다시 생성', ghost: _drafts.isNotEmpty, onPressed: _generate),

            if (_gen?.fallbackUsed ?? false) ...[
              const SizedBox(height: AppSpace.s12),
              Container(
                padding: const EdgeInsets.all(AppSpace.s12),
                decoration: BoxDecoration(color: c.cautionary.withValues(alpha: 0.1), borderRadius: AppRadius.b12),
                child: Text('AI 연결이 없어 기본 문제 골격으로 만들었어요. 정답을 확인·보완한 뒤 배포해주세요.',
                    style: AppType.body2.copyWith(color: c.labelNeutral)),
              ),
            ],

            if (_drafts.isNotEmpty) ...[
              const SizedBox(height: AppSpace.s20),
              SectionLabel('문제 ($validCount개) — 검토·수정'),
              ...List.generate(_drafts.length, (i) => _qEditor(c, i)),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _drafts.add(_QDraft(type: _types.isEmpty ? QuestionType.shortAnswer : _types.first))),
                  icon: Icon(Icons.add, size: 18, color: c.accent),
                  label: Text('빈 문제 추가', style: AppType.label1.copyWith(color: c.accent)),
                ),
              ),
              const SizedBox(height: AppSpace.s12),
              SectionLabel('배포 대상 (${_selected.length}/${students.length})'),
              if (students.isEmpty)
                Text('교실에 추가된 학생이 없어요. ‘교실’에서 학생을 먼저 추가해주세요.', style: AppType.body2.copyWith(color: c.labelAlt))
              else
                ...students.map((l) => _studentCheck(c, l)),
            ],

            if (_error != null) ...[
              const SizedBox(height: AppSpace.s12),
              Text(_error!, style: AppType.body2.copyWith(color: c.negative)),
            ],
            const SizedBox(height: AppSpace.s24),
            if (_drafts.isNotEmpty)
              _saving
                  ? Center(child: CircularProgressIndicator(color: c.accent))
                  : OclButton('문제 배포하기', onPressed: _save),
          ],
        ),
      ),
    );
  }

  Widget _qEditor(AppColors c, int i) {
    final d = _drafts[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s8),
      child: OclCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('${i + 1}', style: AppType.label2.copyWith(color: c.labelAlt)),
                const SizedBox(width: AppSpace.s8),
                Expanded(
                  child: Wrap(spacing: 6, children: QuestionType.values
                      .map((t) => _chip(context, t.label, d.type == t, () => setState(() => d.type = t)))
                      .toList()),
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 18, color: c.labelAssistive),
                  onPressed: () => setState(() => _drafts.removeAt(i).dispose()),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.s8),
            TextField(controller: d.prompt, maxLines: null, style: AppType.body1.copyWith(color: c.labelNormal), decoration: _dec(c, '지문 (빈칸은 ____)')),
            if (d.type == QuestionType.multipleChoice) ...[
              const SizedBox(height: AppSpace.s8),
              TextField(controller: d.choices, maxLines: 4, style: AppType.body2.copyWith(color: c.labelNormal), decoration: _dec(c, '보기 (한 줄에 하나)')),
            ],
            const SizedBox(height: AppSpace.s8),
            TextField(controller: d.answer, style: AppType.body1.copyWith(color: c.labelNormal), decoration: _dec(c, '정답')),
            const SizedBox(height: AppSpace.s8),
            TextField(controller: d.explanation, style: AppType.body2.copyWith(color: c.labelNormal), decoration: _dec(c, '해설 (선택)')),
          ],
        ),
      ),
    );
  }

  Widget _studentCheck(AppColors c, ClassroomMember m) {
    final on = _selected.contains(m.userUid);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s8),
      child: InkWell(
        borderRadius: AppRadius.b14,
        onTap: () => setState(() => on ? _selected.remove(m.userUid) : _selected.add(m.userUid)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16, vertical: AppSpace.s12),
          decoration: BoxDecoration(
            color: on ? c.accentSoft : c.bgElevated,
            borderRadius: AppRadius.b14,
            border: Border.all(color: on ? c.accent : c.lineAlt),
          ),
          child: Row(
            children: [
              Icon(on ? Icons.check_circle : Icons.circle_outlined, size: 22, color: on ? c.accent : c.labelAssistive),
              const SizedBox(width: AppSpace.s12),
              Text(m.displayName.isEmpty ? '이름 미설정' : m.displayName, style: AppType.body1),
            ],
          ),
        ),
      ),
    );
  }
}

/// 선생님 · 세트 상세(학생별 결과 실시간 + 문제 미리보기 + 비용).
class TeacherQuestionDetailPage extends ConsumerWidget {
  final AiQuestionSet set;
  const TeacherQuestionDetailPage({super.key, required this.set});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final results = ref.watch(resultsForSetProvider(set.id)).value ?? const {};
    final questions = ref.watch(questionsForSetProvider(set.id)).value ?? const [];
    final names = {
      for (final m in (ref.watch(teacherStudentsProvider).value ?? const <ClassroomMember>[]))
        m.userUid: m.displayName,
    };
    final total = set.studentUids.length;
    final done = set.studentUids.where((u) => results[u]?.isDone ?? false).length;

    return Scaffold(
      appBar: _bar(context, set.title, back: true, actions: [
        IconButton(icon: Icon(Icons.delete_outline, color: c.labelAlt), onPressed: () => _confirmDelete(context, ref)),
      ]),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpace.s20),
          children: [
            Text(['문제 ${set.questionCount}개', set.difficulty.label, if (set.fromDeck) '카드 연계'].join(' · '),
                style: AppType.body2.copyWith(color: c.labelAlt)),
            const SizedBox(height: AppSpace.s8),
            // 비용/생성 출처
            Text(
              set.fallbackUsed
                  ? '생성: 오프라인 기본(AI 미사용)'
                  : 'AI 모델: ${set.aiModel.isEmpty ? '-' : set.aiModel} · 토큰 ${set.aiTotalTokens}',
              style: AppType.caption1.copyWith(color: c.labelAssistive),
            ),
            const SizedBox(height: AppSpace.s16),
            OclCard(
              child: Row(children: [
                Text('완료', style: AppType.headline2),
                const Spacer(),
                Text('$done / $total명', style: AppType.headline1.copyWith(color: c.accent)),
              ]),
            ),
            const SizedBox(height: AppSpace.s20),
            const SectionLabel('학생별 결과'),
            ...set.studentUids.map((u) {
              final r = results[u];
              final name = (names[u] ?? r?.studentName ?? '').trim();
              return _studentResult(context, name.isEmpty ? '이름 미설정' : name, r);
            }),
            const SizedBox(height: AppSpace.s20),
            const SectionLabel('문제 미리보기'),
            ...questions.map((q) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.s8),
                  child: OclCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: c.fill, borderRadius: AppRadius.bFull),
                            child: Text(q.type.label, style: AppType.caption1.copyWith(color: c.labelAlt)),
                          ),
                        ]),
                        const SizedBox(height: 6),
                        Text(q.prompt, style: AppType.body1.copyWith(color: c.labelNormal)),
                        const SizedBox(height: 4),
                        Text('정답: ${q.answer}', style: AppType.body2.copyWith(color: c.accent)),
                      ],
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _studentResult(BuildContext context, String name, AiQuestionResult? r) {
    final c = context.c;
    final done = r?.isDone ?? false;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s8),
      child: OclCard(
        child: Row(
          children: [
            Expanded(child: Text(name, style: AppType.body1)),
            if (done)
              Text('${r!.correctCount}/${r.total} · ${r.correctPercent}%',
                  style: AppType.body1.copyWith(color: c.accent, fontWeight: FontWeight.w700))
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.s8, vertical: 3),
                decoration: BoxDecoration(color: c.fill, borderRadius: AppRadius.bFull),
                child: Text('미응시', style: AppType.caption1.copyWith(color: c.labelAlt)),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('세트를 삭제할까요?'),
        content: const Text('문제와 학생 결과가 함께 삭제돼요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('삭제')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(aiQuestionRepositoryProvider).deleteSet(set.id);
      if (context.mounted) context.pop();
    }
  }
}
