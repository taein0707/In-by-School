import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/battle_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/battle/battle.dart';
import '../../domain/flashcard/flashcard_deck.dart';
import '../../shared/widgets/ui.dart';

/// 교사: 기존 단어 세트(덱)로 경쟁전을 즉시 생성. 5초 내 생성이 목표.
class BattleCreatePage extends ConsumerStatefulWidget {
  final FlashcardDeck deck;
  const BattleCreatePage({super.key, required this.deck});
  @override
  ConsumerState<BattleCreatePage> createState() => _BattleCreatePageState();
}

class _BattleCreatePageState extends ConsumerState<BattleCreatePage> {
  int _count = 20;
  int _timeLimit = 300; // 5분
  BattleDifficulty _difficulty = BattleDifficulty.normal;
  int _ratio = 75;
  BattleDirection _direction = BattleDirection.enToKo;
  bool _busy = false;

  Future<void> _create() async {
    setState(() => _busy = true);
    try {
      final session = await ref.read(battleRepositoryProvider).createFromDeck(
            deck: widget.deck,
            questionCount: _count,
            timeLimitSec: _timeLimit,
            difficulty: _difficulty,
            choiceRatio: _ratio,
            direction: _direction,
          );
      if (mounted) context.pushReplacement('/battle/live', extra: session.id);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final choice = ((_count * _ratio) / 100).round().clamp(0, _count);
    final short = _count - choice;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => context.pop()),
        title: Text('단어 경쟁전 만들기', style: AppType.headline1),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpace.s20),
                children: [
                  OclCard(
                    child: Row(children: [
                      Icon(Icons.style_outlined, color: c.accent),
                      const SizedBox(width: AppSpace.s12),
                      Expanded(child: Text(widget.deck.title, style: AppType.headline2)),
                      Text('${widget.deck.cardCount}단어', style: AppType.body2.copyWith(color: c.labelAlt)),
                    ]),
                  ),
                  const SizedBox(height: AppSpace.s16),
                  const SectionLabel('문제 수'),
                  _chips<int>(context, const {10: '10문제', 20: '20문제', 30: '30문제'}, _count,
                      (v) => setState(() => _count = v),
                      extra: _CountStepper(value: _count, onChanged: (v) => setState(() => _count = v))),
                  const SizedBox(height: AppSpace.s16),
                  const SectionLabel('제한 시간'),
                  _chips<int>(context, const {180: '3분', 300: '5분', 600: '10분', 0: '제한 없음'},
                      _timeLimit, (v) => setState(() => _timeLimit = v)),
                  const SizedBox(height: AppSpace.s16),
                  const SectionLabel('문제 방식 (선택형 비율)'),
                  _chips<int>(context, const {100: '100%', 75: '75%', 50: '50%', 25: '25%', 0: '0%'},
                      _ratio, (v) => setState(() => _ratio = v)),
                  const SizedBox(height: AppSpace.s8),
                  Text('선택형 $choice문제 · 단답형 $short문제 자동 생성',
                      style: AppType.body2.copyWith(color: c.labelAlt)),
                  const SizedBox(height: AppSpace.s16),
                  const SectionLabel('방향'),
                  _chips<BattleDirection>(
                      context,
                      {for (final d in BattleDirection.values) d: d.label},
                      _direction,
                      (v) => setState(() => _direction = v)),
                  const SizedBox(height: AppSpace.s16),
                  const SectionLabel('난이도'),
                  _chips<BattleDifficulty>(
                      context,
                      {for (final d in BattleDifficulty.values) d: d.label},
                      _difficulty,
                      (v) => setState(() => _difficulty = v)),
                  const SizedBox(height: AppSpace.s24),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.s20, 0, AppSpace.s20, AppSpace.s12),
              child: OclButton(_busy ? '생성 중…' : '경쟁전 시작', onPressed: _busy ? null : _create),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chips<T>(BuildContext context, Map<T, String> options, T selected, ValueChanged<T> onTap,
      {Widget? extra}) {
    return Wrap(
      spacing: AppSpace.s8,
      runSpacing: AppSpace.s8,
      children: [
        ...options.entries.map((e) => _Chip(label: e.value, selected: selected == e.key, onTap: () => onTap(e.key))),
        if (extra != null) extra,
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: selected ? c.accent : c.fill,
      borderRadius: AppRadius.bFull,
      child: InkWell(
        borderRadius: AppRadius.bFull,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
          child: Text(label, style: AppType.label1.copyWith(color: selected ? Colors.white : c.labelNeutral)),
        ),
      ),
    );
  }
}

class _CountStepper extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _CountStepper({required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final custom = value != 10 && value != 20 && value != 30;
    return Material(
      color: custom ? c.accent : c.fill,
      borderRadius: AppRadius.bFull,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => onChanged((value - 5).clamp(5, 100)),
            icon: Icon(Icons.remove, size: 18, color: custom ? Colors.white : c.labelNeutral),
          ),
          Text('직접 $value', style: AppType.label1.copyWith(color: custom ? Colors.white : c.labelNeutral)),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => onChanged((value + 5).clamp(5, 100)),
            icon: Icon(Icons.add, size: 18, color: custom ? Colors.white : c.labelNeutral),
          ),
        ]),
      ),
    );
  }
}
