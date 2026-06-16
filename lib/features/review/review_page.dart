import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_providers.dart';
import '../../app/flashcard_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/flashcard/card_review.dart';
import '../../domain/flashcard/flashcard_deck.dart';
import '../../domain/growth/growth.dart';

/// 오늘 복습 러너(Phase B 핵심 경험) — 여러 덱의 '오늘 복습' 카드를 한 흐름으로 모아
/// 자가 평가(모름/보통/암기완료) → SRS 재스케줄 → 완료 시 토리 XP(awardXp) 지급.
class ReviewPage extends ConsumerStatefulWidget {
  const ReviewPage({super.key});
  @override
  ConsumerState<ReviewPage> createState() => _ReviewState();
}

class _DueItem {
  final FlashcardDeck deck;
  final Flashcard card;
  final CardReview prev;
  const _DueItem(this.deck, this.card, this.prev);
}

class _ReviewState extends ConsumerState<ReviewPage> {
  List<_DueItem>? _items; // null = 로딩 중
  int _i = 0;
  bool _flipped = false;
  bool _saving = false;
  int _reviewed = 0;
  final Map<String, Map<String, CardReview>> _pending = {}; // deckId → {cardId: 새 상태}
  final Map<String, FlashcardDeck> _deckById = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final due = ref.read(dueReviewsProvider);
    final decks = ref.read(studentDecksProvider).value ?? const <FlashcardDeck>[];
    final progress = ref.read(myFlashcardProgressProvider).value ?? const {};
    for (final d in decks) {
      _deckById[d.id] = d;
    }
    final byDeck = <String, Set<String>>{};
    for (final dc in due) {
      byDeck.putIfAbsent(dc.deckId, () => <String>{}).add(dc.cardId);
    }
    final items = <_DueItem>[];
    for (final entry in byDeck.entries) {
      final deck = _deckById[entry.key];
      if (deck == null) continue;
      final cards = await ref.read(flashcardRepositoryProvider).fetchCardsForStudent(entry.key);
      final reviews = progress[entry.key]?.reviews ?? const {};
      for (final card in cards) {
        if (entry.value.contains(card.id)) {
          items.add(_DueItem(deck, card, reviews[card.id] ?? CardReview.fresh(card.id)));
        }
      }
    }
    if (!mounted) return;
    setState(() => _items = items);
  }

  Future<void> _grade(SelfGrade g) async {
    final items = _items!;
    final item = items[_i];
    _pending.putIfAbsent(item.deck.id, () => {})[item.card.id] = Srs.schedule(item.prev, g, DateTime.now());
    _reviewed++;
    if (_i + 1 >= items.length) {
      await _finish();
    } else {
      setState(() {
        _i++;
        _flipped = false;
      });
    }
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    final repo = ref.read(flashcardRepositoryProvider);
    for (final entry in _pending.entries) {
      final deck = _deckById[entry.key];
      if (deck == null) continue;
      await repo.saveCardReviews(deck: deck, reviews: entry.value);
    }
    // 복습 완료 보상 — 기존 통합 API. Life 와 무관(P0).
    if (_reviewed > 0) {
      ref.read(appProvider.notifier).awardXp(XpSource.flashcardReview, XpSource.flashcardReview.defaultXp);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('오늘 복습 완료 — $_reviewed장 다시 봤어요!')),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final items = _items;

    if (items == null || _saving) {
      return Scaffold(appBar: _bar(context), body: Center(child: CircularProgressIndicator(color: c.accent)));
    }
    if (items.isEmpty) {
      return Scaffold(
        appBar: _bar(context),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.s32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_outline, size: 48, color: c.labelAssistive),
                const SizedBox(height: AppSpace.s12),
                Text('오늘 복습할 카드가 없어요.', style: AppType.body1.copyWith(color: c.labelAlt)),
              ],
            ),
          ),
        ),
      );
    }

    final item = items[_i];
    final card = item.card;
    final progress = (_i + 1) / items.length;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text('오늘 복습 · ${_i + 1} / ${items.length}', style: AppType.headline2),
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
              const SizedBox(height: AppSpace.s8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(item.deck.title, style: AppType.caption1.copyWith(color: c.labelAssistive)),
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
              Row(
                children: [
                  Expanded(child: _gradeBtn(c, '모름', c.negative, SelfGrade.unknown)),
                  const SizedBox(width: AppSpace.s8),
                  Expanded(child: _gradeBtn(c, '보통', c.cautionary, SelfGrade.normal)),
                  const SizedBox(width: AppSpace.s8),
                  Expanded(child: _gradeBtn(c, '암기 완료', c.positive, SelfGrade.known)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
          child: Center(
            child: Text(label, style: AppType.label1.copyWith(color: color, fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _bar(BuildContext context) => AppBar(
        backgroundColor: context.c.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text('오늘 복습', style: AppType.headline2),
        leading: IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => context.pop()),
      );
}
