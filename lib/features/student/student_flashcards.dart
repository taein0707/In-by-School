import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/account_providers.dart';
import '../../app/app_providers.dart';
import '../../app/flashcard_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/flashcard/card_review.dart';
import '../../domain/flashcard/flashcard_deck.dart';
import '../../domain/growth/growth.dart';
import '../../shared/widgets/ui.dart';

PreferredSizeWidget _bar(BuildContext context, String title, {bool back = false, Widget? leading}) {
  final c = context.c;
  return AppBar(
    backgroundColor: c.bg,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    centerTitle: false,
    titleSpacing: back ? 0 : AppSpace.s20,
    leading: leading ?? (back ? IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => context.pop()) : null),
    title: Text(title, style: AppType.headline1),
  );
}

/// 학생 학습 화면으로 넘기는 인자(덱 + 모드).
class FlashcardStudyArgs {
  final FlashcardDeck deck;
  final bool selfEval; // true=자가 평가(3단계), false=일반 학습(2단계)
  const FlashcardStudyArgs(this.deck, {required this.selfEval});
}

/// 학습 결과 화면으로 넘기는 인자.
class FlashcardResult {
  final String deckTitle;
  final int total;
  final int studied;
  final double correctRate;
  final double completionRate;
  final int minutes;
  const FlashcardResult({
    required this.deckTitle,
    required this.total,
    required this.studied,
    required this.correctRate,
    required this.completionRate,
    required this.minutes,
  });
}

/// 학생 · 플래시카드 탭 — 새 카드 / 학습 중 / 완료로 그룹핑.
class StudentFlashcardsPage extends ConsumerWidget {
  const StudentFlashcardsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final async = ref.watch(studentDecksProvider);
    final prog = ref.watch(myFlashcardProgressProvider).value ?? const <String, FlashcardProgress>{};

    return Scaffold(
      appBar: _bar(context, '플래시 카드'),
      body: SafeArea(
        top: false,
        child: async.when(
          loading: () => Center(child: CircularProgressIndicator(color: c.accent)),
          error: (e, _) => Center(child: Text('불러오지 못했어요.', style: AppType.body2.copyWith(color: c.labelAlt))),
          data: (list) => list.isEmpty ? _empty(context) : _grouped(context, list, prog),
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
            Icon(Icons.style_outlined, size: 48, color: c.labelAssistive),
            const SizedBox(height: AppSpace.s12),
            Text('받은 카드가 없어요.', style: AppType.body1.copyWith(color: c.labelAlt)),
          ],
        ),
      ),
    );
  }

  Widget _grouped(BuildContext context, List<FlashcardDeck> list, Map<String, FlashcardProgress> prog) {
    final fresh = <FlashcardDeck>[];
    final learning = <FlashcardDeck>[];
    final done = <FlashcardDeck>[];
    for (final d in list) {
      switch (prog[d.id]?.status ?? DeckStudyStatus.fresh) {
        case DeckStudyStatus.done:
          done.add(d);
        case DeckStudyStatus.learning:
          learning.add(d);
        case DeckStudyStatus.fresh:
          fresh.add(d);
      }
    }

    Widget section(String label, List<FlashcardDeck> decks) {
      if (decks.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(label),
          ...decks.map((d) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.s8),
              child: _DeckRow(deck: d, progress: prog[d.id]))),
          const SizedBox(height: AppSpace.s12),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpace.s20),
      children: [
        section('새 카드', fresh),
        section('학습 중', learning),
        section('완료', done),
      ],
    );
  }
}

class _DeckRow extends StatelessWidget {
  final FlashcardDeck deck;
  final FlashcardProgress? progress;
  const _DeckRow({required this.deck, this.progress});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return InkWell(
      borderRadius: AppRadius.b16,
      onTap: () => _pickMode(context),
      child: OclCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(deck.title, style: AppType.headline2),
            const SizedBox(height: 6),
            Text(
              [
                if (deck.teacherName.isNotEmpty) '${deck.teacherName} 선생님',
                if (deck.subject?.isNotEmpty ?? false) deck.subject!,
                '카드 ${deck.cardCount}장',
              ].join(' · '),
              style: AppType.body2.copyWith(color: c.labelAlt),
            ),
            if (progress != null && progress!.studiedCards > 0) ...[
              const SizedBox(height: 6),
              Text('정답률 ${progress!.correctPercent}% · 완료율 ${progress!.completionPercent}%',
                  style: AppType.caption1.copyWith(color: c.accent)),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickMode(BuildContext context) async {
    final args = await showModalBottomSheet<FlashcardStudyArgs>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpace.s16),
              child: Text(deck.title, style: AppType.headline2),
            ),
            ListTile(
              leading: const Icon(Icons.style_outlined),
              title: const Text('일반 학습'),
              subtitle: const Text('카드를 넘기며 뜻을 확인해요'),
              onTap: () => Navigator.pop(ctx, FlashcardStudyArgs(deck, selfEval: false)),
            ),
            ListTile(
              leading: const Icon(Icons.fact_check_outlined),
              title: const Text('자가 평가'),
              subtitle: const Text('모름 · 보통 · 암기 완료로 기록해요'),
              onTap: () => Navigator.pop(ctx, FlashcardStudyArgs(deck, selfEval: true)),
            ),
            const SizedBox(height: AppSpace.s8),
          ],
        ),
      ),
    );
    if (args != null && context.mounted) context.push('/flashcards/study', extra: args);
  }
}

/// 학생 · 카드 학습(일반 / 자가 평가 공용).
class StudentDeckStudyPage extends ConsumerStatefulWidget {
  final FlashcardStudyArgs args;
  const StudentDeckStudyPage({super.key, required this.args});
  @override
  ConsumerState<StudentDeckStudyPage> createState() => _StudyState();
}

class _StudyState extends ConsumerState<StudentDeckStudyPage> {
  List<Flashcard>? _cards;
  int _i = 0;
  bool _flipped = false;
  final List<SelfGrade> _grades = [];
  final DateTime _start = DateTime.now();
  bool _startMarked = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cards = await ref.read(flashcardRepositoryProvider).fetchCardsForStudent(widget.args.deck.id);
    if (!mounted) return;
    setState(() => _cards = cards);
    // 학습 시작 — '학습 중' 상태를 즉시 기록(선생님 화면 실시간 반영).
    if (!_startMarked && cards.isNotEmpty) {
      _startMarked = true;
      ref.read(flashcardRepositoryProvider).saveProgress(
            deck: widget.args.deck,
            studentName: ref.read(currentProfileProvider).value?.displayName ?? '',
            studiedCards: 0,
            totalCards: cards.length,
            studySeconds: 0,
            correctRate: 0,
            completed: false,
          );
    }
  }

  Future<void> _grade(SelfGrade g) async {
    final cards = _cards!;
    _grades.add(g);
    if (_i + 1 >= cards.length) {
      await _finish(cards);
    } else {
      setState(() {
        _i++;
        _flipped = false;
      });
    }
  }

  Future<void> _finish(List<Flashcard> cards) async {
    final seconds = DateTime.now().difference(_start).inSeconds;
    final correctRate = _grades.isEmpty
        ? 0.0
        : _grades.map((g) => g.weight).reduce((a, b) => a + b) / _grades.length;
    await ref.read(flashcardRepositoryProvider).saveProgress(
          deck: widget.args.deck,
          studentName: ref.read(currentProfileProvider).value?.displayName ?? '',
          studiedCards: _grades.length,
          totalCards: cards.length,
          studySeconds: seconds,
          correctRate: correctRate,
          completed: true,
        );
    // 카드 단위 SRS 갱신 — 자가 평가로 다음 복습 일정을 계산해 스케줄에 등록(Phase B).
    final now = DateTime.now();
    final prev = ref.read(myFlashcardProgressProvider).value?[widget.args.deck.id]?.reviews ?? const {};
    final updated = <String, CardReview>{};
    for (var i = 0; i < cards.length && i < _grades.length; i++) {
      final base = prev[cards[i].id] ?? CardReview.fresh(cards[i].id);
      updated[cards[i].id] = Srs.schedule(base, _grades[i], now);
    }
    await ref.read(flashcardRepositoryProvider).saveCardReviews(deck: widget.args.deck, reviews: updated);
    // 복습 1회 완료 보상 — Life 와 무관하게 토리 성장에 가산.
    ref.read(appProvider.notifier).awardXp(XpSource.flashcardReview, XpSource.flashcardReview.defaultXp);
    if (!mounted) return;
    context.pushReplacement(
      '/flashcards/result',
      extra: FlashcardResult(
        deckTitle: widget.args.deck.title,
        total: cards.length,
        studied: _grades.length,
        correctRate: correctRate,
        completionRate: cards.isEmpty ? 0 : _grades.length / cards.length,
        minutes: seconds < 60 ? 1 : seconds ~/ 60,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final cards = _cards;
    if (cards == null) {
      return Scaffold(appBar: _bar(context, widget.args.deck.title, back: true), body: Center(child: CircularProgressIndicator(color: c.accent)));
    }
    if (cards.isEmpty) {
      return Scaffold(
        appBar: _bar(context, widget.args.deck.title, back: true),
        body: Center(child: Text('이 덱에는 카드가 없어요.', style: AppType.body1.copyWith(color: c.labelAlt))),
      );
    }
    final card = cards[_i];
    final progress = (_i + 1) / cards.length;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text('${_i + 1} / ${cards.length}', style: AppType.headline2),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => context.pop()),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s24),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: AppRadius.bFull,
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: c.fillStrong,
                  valueColor: AlwaysStoppedAnimation(c.accent),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _flipped = !_flipped),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, anim) => ScaleTransition(
                      scale: Tween(begin: 0.96, end: 1.0).animate(anim),
                      child: FadeTransition(opacity: anim, child: child)),
                  child: Container(
                    key: ValueKey(_flipped),
                    width: double.infinity,
                    height: 280,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(AppSpace.s24),
                    decoration: BoxDecoration(
                      color: _flipped ? c.accentSoft : c.bgElevated,
                      borderRadius: AppRadius.b24,
                      border: Border.all(color: _flipped ? c.accent.withValues(alpha: 0.4) : c.lineAlt),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_flipped ? '뒷면' : '앞면', style: AppType.label2.copyWith(color: c.labelAlt)),
                        const SizedBox(height: AppSpace.s12),
                        Text(_flipped ? card.back : card.front,
                            textAlign: TextAlign.center,
                            style: (_flipped ? AppType.title2 : AppType.display3).copyWith(color: c.labelNormal)),
                        if (!_flipped && card.hint.isNotEmpty) ...[
                          const SizedBox(height: AppSpace.s12),
                          Text('힌트: ${card.hint}', style: AppType.body2.copyWith(color: c.labelAlt)),
                        ],
                        if (_flipped && card.example.isNotEmpty) ...[
                          const SizedBox(height: AppSpace.s12),
                          Text(card.example,
                              textAlign: TextAlign.center, style: AppType.body2.copyWith(color: c.labelNeutral)),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.s12),
              Text('카드를 탭하면 뒤집혀요', style: AppType.caption1.copyWith(color: c.labelAssistive)),
              const Spacer(),
              _actions(c),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actions(AppColors c) {
    if (widget.args.selfEval) {
      return Row(
        children: [
          Expanded(child: _gradeBtn(c, '모름', c.negative, SelfGrade.unknown)),
          const SizedBox(width: AppSpace.s8),
          Expanded(child: _gradeBtn(c, '보통', c.cautionary, SelfGrade.normal)),
          const SizedBox(width: AppSpace.s8),
          Expanded(child: _gradeBtn(c, '암기 완료', c.positive, SelfGrade.known)),
        ],
      );
    }
    return Row(children: [
      Expanded(child: OclButton('몰라요', ghost: true, onPressed: () => _grade(SelfGrade.unknown))),
      const SizedBox(width: AppSpace.s10),
      Expanded(child: OclButton('알아요', onPressed: () => _grade(SelfGrade.known))),
    ]);
  }

  Widget _gradeBtn(AppColors c, String label, Color color, SelfGrade g) {
    return SizedBox(
      height: 56,
      child: Material(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.b16,
        child: InkWell(
          borderRadius: AppRadius.b16,
          onTap: () => _grade(g),
          child: Center(child: Text(label, style: AppType.label1.copyWith(color: color, fontWeight: FontWeight.w700))),
        ),
      ),
    );
  }
}

/// 학생 · 학습 결과(저장은 학습 화면에서 이미 완료, 여기선 표시만).
class StudentFlashcardResultPage extends StatelessWidget {
  final FlashcardResult result;
  const StudentFlashcardResultPage({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final r = result;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpace.s24),
                children: [
                  Text('학습 완료', style: AppType.title2),
                  const SizedBox(height: 4),
                  Text(r.deckTitle, style: AppType.body1.copyWith(color: c.labelAlt)),
                  const SizedBox(height: AppSpace.s20),
                  Row(children: [
                    _stat(context, '${r.studied}/${r.total}', '학습 카드'),
                    const SizedBox(width: AppSpace.s8),
                    _stat(context, '${(r.correctRate * 100).round()}%', '정답률'),
                    const SizedBox(width: AppSpace.s8),
                    _stat(context, '${r.minutes}분', '학습 시간'),
                  ]),
                  const SizedBox(height: AppSpace.s16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpace.s16),
                    decoration: BoxDecoration(color: c.accentSoft, borderRadius: AppRadius.b16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('완료율 ${(r.completionRate * 100).round()}%',
                            style: AppType.label2.copyWith(color: c.accent, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(r.correctRate >= 0.8
                            ? '잘 외웠어요! 며칠 뒤 가볍게 다시 확인해 봐요.'
                            : '모르는 카드는 다시 한 번 학습해 보면 좋아요.',
                            style: AppType.body1.copyWith(color: c.labelNeutral)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.s24, 0, AppSpace.s24, AppSpace.s12),
              child: OclButton('확인', onPressed: () => context.go('/flashcards')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(BuildContext context, String v, String l) {
    final c = context.c;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(color: c.bgAlt, borderRadius: AppRadius.b14),
        child: Column(children: [
          Text(v, style: AppType.title3.copyWith(fontWeight: FontWeight.w700)),
          Text(l, style: AppType.caption1.copyWith(color: c.labelAlt)),
        ]),
      ),
    );
  }
}
