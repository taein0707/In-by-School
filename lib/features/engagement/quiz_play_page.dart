import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/account_providers.dart';
import '../../app/engagement_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/engagement/quiz_competition.dart';
import '../../domain/worksheet/worksheet_question.dart';
import '../../shared/widgets/ui.dart';

/// 퀴즈 대회 플레이(P4-3) — 타이머·실시간 랭킹·재도전 제한·자동 종료.
class QuizPlayPage extends ConsumerStatefulWidget {
  final String competitionId;
  final bool teacher;
  const QuizPlayPage({super.key, required this.competitionId, this.teacher = false});

  @override
  ConsumerState<QuizPlayPage> createState() => _QuizPlayPageState();
}

class _QuizPlayPageState extends ConsumerState<QuizPlayPage> {
  Timer? _ticker;
  final _shortCtrl = TextEditingController();
  int _qi = 0;
  final Map<int, String> _answers = {};
  bool _started = false;
  bool _submitted = false;
  int _attempt = 0;
  bool _autoEnded = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      _maybeAuto();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _shortCtrl.dispose();
    super.dispose();
  }

  void _maybeAuto() {
    final comp = ref.read(quizCompetitionProvider(widget.competitionId)).valueOrNull;
    if (comp == null) return;
    final expired = comp.isExpired(DateTime.now());
    if (!expired) return;
    if (widget.teacher && !_autoEnded && comp.status == QuizStatus.playing) {
      _autoEnded = true;
      ref.read(quizRepositoryProvider).endCompetition(comp.id);
    }
    if (!widget.teacher && _started && !_submitted) {
      _submit(comp);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final comp = ref.watch(quizCompetitionProvider(widget.competitionId)).valueOrNull;
    final players = ref.watch(quizPlayersProvider(widget.competitionId)).valueOrNull ?? const [];

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => context.pop()),
        title: Text(comp?.title.isNotEmpty == true ? comp!.title : '퀴즈 대회', style: AppType.headline1),
      ),
      body: SafeArea(
        child: comp == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(AppSpace.s20),
                children: widget.teacher ? _teacher(c, comp, players) : _student(c, comp, players),
              ),
      ),
    );
  }

  // ---- 교사 ----
  List<Widget> _teacher(AppColors c, QuizCompetition comp, List<QuizPlayer> players) {
    if (comp.status == QuizStatus.waiting) {
      return [
        OclCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${comp.total}문제 · 제한 ${comp.durationSec ~/ 60}분', style: AppType.headline2),
            const SizedBox(height: 4),
            Text('재도전 ${comp.maxAttempts == 0 ? '무제한' : '${comp.maxAttempts}회'}', style: AppType.body2.copyWith(color: c.labelAlt)),
          ]),
        ),
        const SizedBox(height: AppSpace.s16),
        OclButton('대회 시작', onPressed: () => ref.read(quizRepositoryProvider).startCompetition(comp.id)),
      ];
    }
    return [
      _timerBar(c, comp),
      const SizedBox(height: AppSpace.s16),
      if (comp.status == QuizStatus.playing)
        OclButton('지금 종료', ghost: true, onPressed: () => ref.read(quizRepositoryProvider).endCompetition(comp.id)),
      if (comp.status == QuizStatus.playing) const SizedBox(height: AppSpace.s16),
      _ranking(c, players, comp.status == QuizStatus.finished),
    ];
  }

  // ---- 학생 ----
  List<Widget> _student(AppColors c, QuizCompetition comp, List<QuizPlayer> players) {
    final me = ref.watch(authStateProvider).valueOrNull?.uid ?? '';
    final mine = ref.watch(myQuizPlayerProvider(widget.competitionId)).valueOrNull;

    if (comp.status == QuizStatus.waiting) {
      return [_banner(c, '선생님이 시작하면 대회가 시작돼요.', c.bgElevated, c.labelAlt), const SizedBox(height: AppSpace.s16), _ranking(c, players, false)];
    }

    final finishedStatus = comp.status == QuizStatus.finished || comp.isExpired(DateTime.now());

    // 풀이 중
    if (_started && !_submitted && !finishedStatus) {
      return [_timerBar(c, comp), const SizedBox(height: AppSpace.s16), ..._question(c, comp)];
    }

    // 결과/대기 화면
    final myScore = mine?.score ?? 0;
    final canRetry = QuizScoring.canRetry(mine?.attempts ?? 0, comp.maxAttempts);
    return [
      _timerBar(c, comp),
      const SizedBox(height: AppSpace.s16),
      if (mine != null && (mine.finished || _submitted))
        _banner(c, '내 점수 $myScore / ${comp.total}', c.accentSoft, c.accent)
      else
        _banner(c, '대회가 진행 중이에요. 시작해서 참여하세요!', c.bgElevated, c.labelAlt),
      const SizedBox(height: AppSpace.s16),
      if (!finishedStatus)
        if (mine == null || !mine.finished)
          OclButton('시작하기', onPressed: () => _begin(comp, mine, me))
        else if (canRetry)
          OclButton('재도전하기', onPressed: () => _begin(comp, mine, me))
        else
          _banner(c, '재도전 횟수를 모두 사용했어요.', c.bgElevated, c.labelAssistive),
      const SizedBox(height: AppSpace.s16),
      _ranking(c, players, finishedStatus),
    ];
  }

  List<Widget> _question(AppColors c, QuizCompetition comp) {
    final q = comp.questions[_qi];
    final last = _qi == comp.questions.length - 1;
    return [
      Text('${_qi + 1} / ${comp.questions.length}', style: AppType.label1.copyWith(color: c.labelAlt)),
      const SizedBox(height: AppSpace.s8),
      OclCard(child: Text(q.question, style: AppType.headline2)),
      const SizedBox(height: AppSpace.s16),
      ..._answerInput(c, q),
      const SizedBox(height: AppSpace.s20),
      Row(children: [
        if (_qi > 0) Expanded(child: OclButton('이전', ghost: true, onPressed: () => _go(_qi - 1))),
        if (_qi > 0) const SizedBox(width: AppSpace.s8),
        Expanded(child: OclButton(last ? '제출하기' : '다음', onPressed: last ? () => _submit(comp) : () => _go(_qi + 1))),
      ]),
    ];
  }

  List<Widget> _answerInput(AppColors c, WorksheetQuestion q) {
    switch (q.type) {
      case WorksheetQuestionType.multipleChoice:
        return [
          for (final choice in q.choices) _choiceTile(c, choice, _answers[_qi] == choice, () => _setAnswer(choice)),
        ];
      case WorksheetQuestionType.ox:
        return [
          Row(children: [
            Expanded(child: _bigChoice(c, 'O', _answers[_qi] == 'O', () => _setAnswer('O'))),
            const SizedBox(width: AppSpace.s8),
            Expanded(child: _bigChoice(c, 'X', _answers[_qi] == 'X', () => _setAnswer('X'))),
          ]),
        ];
      default: // shortAnswer
        return [
          TextField(
            controller: _shortCtrl,
            style: AppType.body1.copyWith(color: c.labelNormal),
            decoration: InputDecoration(
              hintText: '정답 입력',
              filled: true,
              fillColor: c.bgElevated,
              enabledBorder: OutlineInputBorder(borderRadius: AppRadius.b14, borderSide: BorderSide(color: c.lineAlt)),
              focusedBorder: OutlineInputBorder(borderRadius: AppRadius.b14, borderSide: BorderSide(color: c.accent, width: 2)),
              contentPadding: const EdgeInsets.all(AppSpace.s16),
            ),
            onChanged: _setAnswer,
          ),
        ];
    }
  }

  Widget _choiceTile(AppColors c, String label, bool on, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.s8),
        child: Material(
          color: on ? c.accentSoft : c.bgElevated,
          borderRadius: AppRadius.b14,
          child: InkWell(
            borderRadius: AppRadius.b14,
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(AppSpace.s16),
              decoration: BoxDecoration(borderRadius: AppRadius.b14, border: Border.all(color: on ? c.accent : c.lineAlt)),
              child: Row(children: [
                Icon(on ? Icons.radio_button_checked : Icons.radio_button_off, color: on ? c.accent : c.labelAssistive, size: 20),
                const SizedBox(width: AppSpace.s12),
                Expanded(child: Text(label, style: AppType.body1.copyWith(color: c.labelNeutral))),
              ]),
            ),
          ),
        ),
      );

  Widget _bigChoice(AppColors c, String label, bool on, VoidCallback onTap) => Material(
        color: on ? c.accent : c.bgElevated,
        borderRadius: AppRadius.b16,
        child: InkWell(
          borderRadius: AppRadius.b16,
          onTap: onTap,
          child: Container(
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(borderRadius: AppRadius.b16, border: Border.all(color: on ? c.accent : c.lineAlt)),
            child: Text(label, style: AppType.title2.copyWith(color: on ? Colors.white : c.labelNeutral)),
          ),
        ),
      );

  Widget _timerBar(AppColors c, QuizCompetition comp) {
    final rem = comp.remaining(DateTime.now());
    final frac = comp.durationSec == 0 ? 0.0 : rem.inSeconds / comp.durationSec;
    final mm = (rem.inSeconds ~/ 60).toString().padLeft(2, '0');
    final ss = (rem.inSeconds % 60).toString().padLeft(2, '0');
    final low = rem.inSeconds <= 10 && comp.status == QuizStatus.playing;
    return Row(children: [
      Expanded(
        child: ClipRRect(
          borderRadius: AppRadius.b14,
          child: LinearProgressIndicator(value: frac.clamp(0.0, 1.0), minHeight: 10, backgroundColor: c.fill, color: low ? c.negative : c.accent),
        ),
      ),
      const SizedBox(width: AppSpace.s12),
      Text(comp.status == QuizStatus.finished ? '종료' : '$mm:$ss',
          style: AppType.label1.copyWith(color: low ? c.negative : c.labelNeutral)),
    ]);
  }

  Widget _ranking(AppColors c, List<QuizPlayer> players, bool finished) => OclCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(finished ? '최종 랭킹' : '실시간 랭킹', style: AppType.headline2),
          const SizedBox(height: AppSpace.s8),
          if (players.isEmpty)
            Text('아직 참가자가 없어요.', style: AppType.body2.copyWith(color: c.labelAssistive))
          else
            for (var i = 0; i < players.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  SizedBox(width: 24, child: Text('${i + 1}', style: AppType.label1.copyWith(color: i < 3 ? c.accent : c.labelAlt))),
                  Expanded(child: Text(players[i].studentName.isEmpty ? '학생' : players[i].studentName, style: AppType.body1.copyWith(color: c.labelNeutral))),
                  if (players[i].finished) Icon(Icons.flag, size: 14, color: c.labelAssistive),
                  const SizedBox(width: 6),
                  Text('${players[i].score}점', style: AppType.label1.copyWith(color: c.labelNeutral)),
                ]),
              ),
        ]),
      );

  Widget _banner(AppColors c, String text, Color bg, Color fg) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpace.s16),
        decoration: BoxDecoration(color: bg, borderRadius: AppRadius.b16, border: Border.all(color: fg.withValues(alpha: 0.4))),
        child: Text(text, style: AppType.body1.copyWith(color: fg)),
      );

  // ---- 동작 ----
  void _begin(QuizCompetition comp, QuizPlayer? mine, String me) {
    setState(() {
      _started = true;
      _submitted = false;
      _qi = 0;
      _answers.clear();
      _shortCtrl.clear();
      _attempt = (mine?.attempts ?? 0) + 1;
    });
    final name = ref.read(currentProfileProvider).valueOrNull?.displayName ?? '학생';
    ref.read(quizRepositoryProvider).savePlayer(
        competition: comp, studentName: name, score: 0, answered: 0, attempts: _attempt, finished: false);
  }

  void _go(int index) {
    setState(() {
      _qi = index;
      _shortCtrl.text = _answers[_qi] ?? '';
    });
  }

  void _setAnswer(String value) {
    setState(() {
      if (value.trim().isEmpty) {
        _answers.remove(_qi);
      } else {
        _answers[_qi] = value;
      }
    });
    _saveLive();
  }

  void _saveLive() {
    final comp = ref.read(quizCompetitionProvider(widget.competitionId)).valueOrNull;
    if (comp == null) return;
    final name = ref.read(currentProfileProvider).valueOrNull?.displayName ?? '학생';
    final score = QuizScoring.score(comp.questions, _answers);
    ref.read(quizRepositoryProvider).savePlayer(
        competition: comp, studentName: name, score: score, answered: _answers.length, attempts: _attempt, finished: false);
  }

  void _submit(QuizCompetition comp) {
    if (_submitted) return;
    final name = ref.read(currentProfileProvider).valueOrNull?.displayName ?? '학생';
    final score = QuizScoring.score(comp.questions, _answers);
    ref.read(quizRepositoryProvider).savePlayer(
        competition: comp, studentName: name, score: score, answered: _answers.length, attempts: _attempt, finished: true);
    setState(() {
      _submitted = true;
      _started = false;
    });
  }
}
