import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/account_providers.dart';
import '../../app/engagement_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/engagement/bingo_game.dart';
import '../../shared/widgets/ui.dart';

/// 빙고 플레이(P4-1) — 실시간 턴제. 교사/학생 공용.
class BingoPlayPage extends ConsumerStatefulWidget {
  final String gameId;
  final bool teacher;
  const BingoPlayPage({super.key, required this.gameId, this.teacher = false});

  @override
  ConsumerState<BingoPlayPage> createState() => _BingoPlayPageState();
}

class _BingoPlayPageState extends ConsumerState<BingoPlayPage> {
  final _wordCtrl = TextEditingController();

  @override
  void dispose() {
    _wordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final game = ref.watch(bingoGameProvider(widget.gameId)).valueOrNull;
    final me = ref.watch(authStateProvider).valueOrNull?.uid ?? '';
    final myName = ref.watch(currentProfileProvider).valueOrNull?.displayName ?? '나';

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => context.pop()),
        title: Text(game?.title.isNotEmpty == true ? game!.title : '빙고', style: AppType.headline1),
      ),
      body: SafeArea(
        child: game == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(AppSpace.s20),
                children: _content(context, game, me, myName),
              ),
      ),
    );
  }

  List<Widget> _content(BuildContext context, BingoGame game, String me, String myName) {
    final c = context.c;
    final joined = game.turnOrder.contains(me);

    if (game.isFinished) {
      final winnerName = game.names[game.winner] ?? '우승자';
      return [
        _banner(c, '🎉 $winnerName 님 우승!', c.accentSoft, c.accent),
        const SizedBox(height: AppSpace.s16),
        if (joined) _boardCard(c, game, me),
        const SizedBox(height: AppSpace.s16),
        _calledCard(c, game),
      ];
    }

    if (game.status == BingoStatus.waiting) {
      return [
        OclCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${game.size}×${game.size} · ${game.mode.label}', style: AppType.headline2),
            const SizedBox(height: 4),
            Text('참가자 ${game.turnOrder.length}명', style: AppType.body2.copyWith(color: c.labelAlt)),
            if (game.turnOrder.isNotEmpty) ...[
              const SizedBox(height: AppSpace.s8),
              Wrap(spacing: AppSpace.s8, runSpacing: AppSpace.s8, children: [
                for (final u in game.turnOrder) _chip(c, game.names[u] ?? '학생'),
              ]),
            ],
          ]),
        ),
        const SizedBox(height: AppSpace.s16),
        if (!joined)
          OclButton('참가하기', onPressed: () => ref.read(bingoRepositoryProvider).joinBingo(gameId: game.id, displayName: myName)),
        if (joined && !widget.teacher)
          _banner(c, '참가 완료! 선생님이 시작하면 게임이 진행돼요.', c.bgElevated, c.labelAlt),
        if (widget.teacher) ...[
          if (joined) const SizedBox(height: AppSpace.s8),
          OclButton(
            game.turnOrder.isEmpty ? '참가자를 기다리는 중' : '게임 시작',
            onPressed: game.turnOrder.isEmpty ? null : () => ref.read(bingoRepositoryProvider).startBingo(game.id),
          ),
        ],
      ];
    }

    // playing
    final myTurn = game.currentTurn == me;
    final turnName = game.names[game.currentTurn] ?? '학생';
    return [
      _banner(
        c,
        myTurn ? '내 차례예요! 단어를 부르세요.' : '$turnName 님의 차례',
        myTurn ? c.accentSoft : c.bgElevated,
        myTurn ? c.accent : c.labelAlt,
      ),
      const SizedBox(height: AppSpace.s16),
      if (!joined)
        OclButton('참가하기', onPressed: () => ref.read(bingoRepositoryProvider).joinBingo(gameId: game.id, displayName: myName))
      else ...[
        _boardCard(c, game, me),
        const SizedBox(height: AppSpace.s16),
        if (myTurn) _callRow(c, game),
      ],
      const SizedBox(height: AppSpace.s16),
      _calledCard(c, game),
    ];
  }

  Widget _boardCard(AppColors c, BingoGame game, String me) {
    final board = game.boardOf(me) ?? const [];
    final called = game.calledWords.toSet();
    final marked = BingoLogic.markedCount(board, game.calledWords);
    return OclCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('내 빙고판', style: AppType.headline2),
          const Spacer(),
          Text('$marked/${board.where((w) => w.isNotEmpty).length}칸', style: AppType.body2.copyWith(color: c.labelAlt)),
        ]),
        const SizedBox(height: AppSpace.s12),
        GridView.count(
          crossAxisCount: game.size,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpace.s8,
          crossAxisSpacing: AppSpace.s8,
          childAspectRatio: 1,
          children: [
            for (final w in board)
              Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: w.isNotEmpty && called.contains(w) ? c.accent : c.bg,
                  borderRadius: AppRadius.b14,
                  border: Border.all(color: w.isNotEmpty && called.contains(w) ? c.accent : c.lineAlt),
                ),
                child: Text(
                  w,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.body2.copyWith(color: w.isNotEmpty && called.contains(w) ? Colors.white : c.labelNeutral),
                ),
              ),
          ],
        ),
      ]),
    );
  }

  Widget _callRow(AppColors c, BingoGame game) => Row(children: [
        Expanded(
          child: TextField(
            controller: _wordCtrl,
            style: AppType.body1.copyWith(color: c.labelNormal),
            decoration: InputDecoration(
              hintText: '부를 단어',
              filled: true,
              fillColor: c.bgElevated,
              enabledBorder: OutlineInputBorder(borderRadius: AppRadius.b14, borderSide: BorderSide(color: c.lineAlt)),
              focusedBorder: OutlineInputBorder(borderRadius: AppRadius.b14, borderSide: BorderSide(color: c.accent, width: 2)),
              contentPadding: const EdgeInsets.all(AppSpace.s14),
            ),
            onSubmitted: (_) => _call(game),
          ),
        ),
        const SizedBox(width: AppSpace.s8),
        SizedBox(
          height: 52,
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: c.accent, shape: RoundedRectangleBorder(borderRadius: AppRadius.b14)),
            onPressed: () => _call(game),
            child: Text('부르기', style: AppType.label1.copyWith(color: Colors.white)),
          ),
        ),
      ]);

  void _call(BingoGame game) {
    final w = _wordCtrl.text.trim();
    if (w.isEmpty) return;
    ref.read(bingoRepositoryProvider).callWord(gameId: game.id, word: w);
    _wordCtrl.clear();
  }

  Widget _calledCard(AppColors c, BingoGame game) => OclCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('호출된 단어 (${game.calledWords.length})', style: AppType.headline2),
          const SizedBox(height: AppSpace.s8),
          if (game.calledWords.isEmpty)
            Text('아직 없어요.', style: AppType.body2.copyWith(color: c.labelAssistive))
          else
            Wrap(spacing: AppSpace.s8, runSpacing: AppSpace.s8, children: [
              for (final w in game.calledWords) _chip(c, w),
            ]),
        ]),
      );

  Widget _chip(AppColors c, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.s12, vertical: 6),
        decoration: BoxDecoration(color: c.bg, borderRadius: AppRadius.b14, border: Border.all(color: c.lineAlt)),
        child: Text(text, style: AppType.body2.copyWith(color: c.labelNeutral)),
      );

  Widget _banner(AppColors c, String text, Color bg, Color fg) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpace.s16),
        decoration: BoxDecoration(color: bg, borderRadius: AppRadius.b16, border: Border.all(color: fg.withValues(alpha: 0.4))),
        child: Text(text, style: AppType.body1.copyWith(color: fg)),
      );
}
