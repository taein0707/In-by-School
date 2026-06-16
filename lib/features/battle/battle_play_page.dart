import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/battle_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/battle/battle.dart';
import '../../domain/battle/battle_engine.dart';
import '../../shared/widgets/ui.dart';

/// 학생 풀이 화면. 점수·연속은 보여주되 **등수(순위)는 절대 노출하지 않는다.**
class BattlePlayPage extends ConsumerStatefulWidget {
  final String battleId;
  const BattlePlayPage({super.key, required this.battleId});
  @override
  ConsumerState<BattlePlayPage> createState() => _BattlePlayPageState();
}

class _BattlePlayPageState extends ConsumerState<BattlePlayPage> {
  BattleSession? _battle;
  String _uid = '';
  int _i = 0;
  int _score = 0;
  int _streak = 0;
  int _maxStreak = 0;
  int _correct = 0;
  int _wrong = 0;
  String? _picked; // 선택형: 고른 보기
  bool _answered = false;
  String _msg = '🌟 계속 도전해보세요';
  final _short = TextEditingController();
  late final DateTime _start = DateTime.now();
  Timer? _timer;
  int _remaining = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _short.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = ref.read(battleRepositoryProvider);
    _uid = await repo.ensureUser();
    final s = await repo.watchBattle(widget.battleId).first;
    if (!mounted) return;
    setState(() {
      _battle = s;
      _loading = false;
      _remaining = s?.timeLimitSec ?? 0;
    });
    if (s != null && !s.unlimitedTime) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _remaining = (_remaining - 1).clamp(0, 1 << 30));
        if (_remaining <= 0) _finish();
      });
    }
  }

  Future<void> _answer(bool correct, String picked) async {
    if (_answered) return;
    final r = BattleEngine.score(prevStreak: _streak, correct: correct);
    setState(() {
      _answered = true;
      _picked = picked;
      _score += r.points;
      _streak = r.streak;
      _maxStreak = _maxStreak < _streak ? _streak : _maxStreak;
      if (correct) {
        _correct++;
      } else {
        _wrong++;
      }
      _msg = BattleEngine.motivation(_streak);
    });
    await _sync(finished: false);
    await Future.delayed(const Duration(milliseconds: 750));
    if (!mounted) return;
    _next();
  }

  void _next() {
    final total = _battle?.questions.length ?? 0;
    if (_i + 1 >= total) {
      _finish();
    } else {
      setState(() {
        _i++;
        _answered = false;
        _picked = null;
        _short.clear();
      });
    }
  }

  Future<void> _sync({required bool finished}) async {
    await ref.read(battleRepositoryProvider).submitStats(
          battleId: widget.battleId,
          uid: _uid,
          score: _score,
          streak: _streak,
          maxStreak: _maxStreak,
          correctCount: _correct,
          wrongCount: _wrong,
          durationSeconds: DateTime.now().difference(_start).inSeconds,
          finished: finished,
        );
  }

  Future<void> _finish() async {
    _timer?.cancel();
    await _sync(finished: true);
    if (!mounted) return;
    context.pushReplacement('/battle/result', extra: widget.battleId);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final battle = _battle;
    if (_loading) {
      return Scaffold(appBar: _bar(context), body: Center(child: CircularProgressIndicator(color: c.accent)));
    }
    if (battle == null || battle.questions.isEmpty) {
      return Scaffold(
        appBar: _bar(context),
        body: Center(child: Text('문제를 불러오지 못했어요.', style: AppType.body1.copyWith(color: c.labelAlt))),
      );
    }
    final q = battle.questions[_i];
    final progress = (_i + 1) / battle.questions.length;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text('${_i + 1} / ${battle.questions.length}', style: AppType.headline2),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => context.pop()),
        actions: [
          if (!battle.unlimitedTime)
            Center(
                child: Padding(
              padding: const EdgeInsets.only(right: AppSpace.s16),
              child: Text(_mmss(_remaining), style: AppType.headline2.copyWith(color: c.accent)),
            )),
        ],
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
              const SizedBox(height: AppSpace.s12),
              // 점수 + 동기부여(순위 없음)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('$_score점', style: AppType.headline2.copyWith(color: c.labelNormal)),
                  Text(_msg, style: AppType.label1.copyWith(color: c.accent)),
                ],
              ),
              const Spacer(),
              Text(q.prompt, textAlign: TextAlign.center, style: AppType.display3.copyWith(color: c.labelNormal)),
              const SizedBox(height: AppSpace.s24),
              if (q.type == BattleQType.choice)
                ...q.choices.map((opt) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.s8),
                      child: _choice(c, opt, q.answer),
                    ))
              else
                _shortInput(c, q.answer),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _choice(AppColors c, String opt, String answer) {
    Color bg = c.bgElevated;
    Color border = c.lineAlt;
    if (_answered) {
      if (opt == answer) {
        bg = c.positive.withValues(alpha: 0.15);
        border = c.positive;
      } else if (opt == _picked) {
        bg = c.negative.withValues(alpha: 0.15);
        border = c.negative;
      }
    }
    return Material(
      color: bg,
      borderRadius: AppRadius.b14,
      child: InkWell(
        borderRadius: AppRadius.b14,
        onTap: _answered ? null : () => _answer(opt == answer, opt),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpace.s16),
          decoration: BoxDecoration(borderRadius: AppRadius.b14, border: Border.all(color: border)),
          child: Text(opt, style: AppType.body1.copyWith(color: c.labelNormal)),
        ),
      ),
    );
  }

  Widget _shortInput(AppColors c, String answer) {
    return Column(
      children: [
        TextField(
          controller: _short,
          enabled: !_answered,
          textAlign: TextAlign.center,
          style: AppType.title3.copyWith(color: c.labelNormal),
          decoration: InputDecoration(
            hintText: '정답 입력',
            filled: true,
            fillColor: c.bgElevated,
            enabledBorder:
                OutlineInputBorder(borderRadius: AppRadius.b14, borderSide: BorderSide(color: c.lineAlt)),
            focusedBorder: OutlineInputBorder(
                borderRadius: AppRadius.b14, borderSide: BorderSide(color: c.accent, width: 2)),
            contentPadding: const EdgeInsets.all(AppSpace.s16),
          ),
          onSubmitted: (_) => _submitShort(answer),
        ),
        if (_answered && _picked != answer) ...[
          const SizedBox(height: AppSpace.s8),
          Text('정답: $answer', style: AppType.body2.copyWith(color: c.positive)),
        ],
        const SizedBox(height: AppSpace.s12),
        OclButton('제출', onPressed: _answered ? null : () => _submitShort(answer)),
      ],
    );
  }

  void _submitShort(String answer) {
    final given = _short.text;
    _answer(BattleEngine.isShortCorrect(given, answer), given.trim());
  }

  String _mmss(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  PreferredSizeWidget _bar(BuildContext context) => AppBar(
        backgroundColor: context.c.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text('단어 경쟁전', style: AppType.headline2),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => context.pop()),
      );
}
