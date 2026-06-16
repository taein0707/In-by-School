import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_providers.dart';
import '../../app/settings_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/study/study_mode.dart';
import '../../domain/study/study_session.dart';
import '../../data/ai/gemini_service.dart';
import '../../data/notifications/notification_service.dart';
import '../../shared/widgets/tori_spirit.dart';
import '../../shared/widgets/ui.dart';
import 'session_config.dart';

/// 공부 중 — 집중 중심, 최소 UI. 실제 시계 기준.
class StudyActivePage extends ConsumerStatefulWidget {
  final SessionConfig config;
  const StudyActivePage({super.key, required this.config});
  @override
  ConsumerState<StudyActivePage> createState() => _StudyActivePageState();
}

class _StudyActivePageState extends ConsumerState<StudyActivePage> {
  static const int _workSec = 25 * 60, _breakSec = 5 * 60;

  Timer? _timer;
  int _elapsed = 0; // total seconds
  int _workSeconds = 0; // counted study seconds
  bool _writing = false; // blank-recall write step
  bool _analyzing = false;
  bool _quizInput = false; // 문제풀이 정답 입력 단계
  int _qCorrect = 8, _qTotal = 10;
  final _blankCtrl = TextEditingController();

  bool get _isPomodoro => widget.config.mode == StudyMode.pomodoro;
  bool get _onBreak => _isPomodoro && (_elapsed % (_workSec + _breakSec)) >= _workSec;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _elapsed++;
        if (!_onBreak) _workSeconds++;
      });
    });
    // 잠금화면 상주 카운트업 (Live Update)
    NotificationService.showStudyTimer(
      startEpochMs: DateTime.now().millisecondsSinceEpoch,
      label: '${StudyModeInfo.of(widget.config.mode).name} · ${widget.config.subject}',
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    NotificationService.cancelStudyTimer();
    _blankCtrl.dispose();
    super.dispose();
  }

  int get _focusedMin => _workSeconds ~/ 60;

  void _finish() {
    _timer?.cancel();
    NotificationService.cancelStudyTimer();
    switch (widget.config.mode) {
      case StudyMode.blank:
        setState(() => _writing = true);
        return;
      case StudyMode.quiz:
        setState(() => _quizInput = true);
        return;
      default:
        _complete(abandoned: false);
    }
  }

  void _abandon() {
    _timer?.cancel();
    NotificationService.cancelStudyTimer();
    _complete(abandoned: true);
  }

  void _complete({required bool abandoned, BlankAnalysis? blank}) {
    final now = DateTime.now();
    final mode = widget.config.mode;

    QuizResult? quiz;
    List<DateTime>? reviewDates;
    ExamPlan? examPlan;
    int? accuracy;
    if (!abandoned) {
      if (mode == StudyMode.quiz) {
        accuracy = (_qCorrect / _qTotal * 100).round();
        quiz = QuizResult(accuracy, _quizNote(accuracy));
      } else if (mode == StudyMode.memory) {
        // 망각곡선 기반 복습 예약 (1·3·7일)
        reviewDates = [
          now.add(const Duration(days: 1)),
          now.add(const Duration(days: 3)),
          now.add(const Duration(days: 7)),
        ];
      } else if (mode == StudyMode.exam) {
        examPlan = _buildExamPlan();
      }
    }

    final session = StudySession(
      mode: mode,
      subject: widget.config.subject,
      focusedMin: _focusedMin,
      goalMin: widget.config.goalMin,
      hour: now.hour,
      date: now,
      accuracy: accuracy,
      abandoned: abandoned,
    );
    final result = ref.read(appProvider.notifier).complete(
          session,
          abandoned: abandoned,
          blank: blank,
          quiz: quiz,
          reviewDates: reviewDates,
          examPlan: examPlan,
        );
    if (!mounted) return;
    // Stage-up is a special, full-screen moment; ordinary sessions show the result.
    if (result.gain.stageUp && !abandoned) {
      context.pushReplacement('/study/evolve');
    } else {
      context.pushReplacement('/study/result');
    }
  }

  String _quizNote(int acc) => acc >= 80
      ? '정답률이 높아요. 틀린 유형만 따로 모아 복습해 봐요.'
      : acc >= 60
          ? '취약 유형이 보여요. 오답을 분류해 다시 풀어봐요.'
          : '기본 개념부터 한 번 더 다지면 정답률이 올라갈 거예요.';

  ExamPlan _buildExamPlan() {
    final sessions = ref.read(appProvider).sessions;
    final bySubject = <String, int>{};
    for (final s in sessions) {
      bySubject[s.subject] = (bySubject[s.subject] ?? 0) + s.focusedMin;
    }
    final sorted = bySubject.keys.toList()
      ..sort((a, b) => (bySubject[b] ?? 0).compareTo(bySubject[a] ?? 0));
    final subs = sorted.isNotEmpty ? sorted.take(3).toList() : [widget.config.subject];
    const ratios = [40, 35, 25];
    final split = [for (int i = 0; i < subs.length; i++) '${subs[i]} ${ratios[i.clamp(0, 2)]}%'];
    final dday = widget.config.examDdays;
    // 시험이 가까울수록 하루 목표를 높게 (동적 배분)
    final dailyMin = dday <= 7 ? 180 : (dday <= 14 ? 150 : (dday <= 30 ? 120 : 90));
    return ExamPlan(dday: dday, dailyMin: dailyMin, split: split);
  }

  // 백지복습 분석: Gemini 호출(키 있으면) → 실패/키 없으면 로컬 휴리스틱 폴백.
  Future<void> _runBlankAnalysis() async {
    setState(() => _analyzing = true);
    final analysis = await GeminiService.analyzeBlankReview(
      subject: widget.config.subject,
      text: _blankCtrl.text,
    );
    if (!mounted) return;
    _complete(abandoned: false, blank: analysis);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final accent = ref.watch(settingsProvider).accent;
    if (_writing) return _buildWrite(context, c);
    if (_quizInput) return _buildQuiz(context, c);

    final goal = widget.config.goalMin;
    double progress;
    String big, sub, top;
    if (_isPomodoro) {
      final inCycle = _elapsed % (_workSec + _breakSec);
      progress = _onBreak ? (inCycle - _workSec) / _breakSec : inCycle / _workSec;
      big = _fmt(_onBreak ? inCycle - _workSec : inCycle);
      sub = _onBreak ? '잠깐 쉬어요' : '집중 $_focusedMin분';
      top = '포모도로 · ${widget.config.subject}${_onBreak ? ' · 휴식' : ''}';
    } else {
      progress = goal > 0 ? (_focusedMin / goal).clamp(0, 1) : (_elapsed % (25 * 60)) / (25 * 60);
      big = _fmt(_elapsed);
      sub = goal > 0 ? '목표 $goal분' : '자유 집중';
      top = '${StudyModeInfo.of(widget.config.mode).name} · ${widget.config.subject}';
    }

    return Scaffold(
      backgroundColor: _onBreak ? c.bgAlt : c.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Text(top, style: AppType.headline2.copyWith(color: c.labelNeutral)),
              const SizedBox(height: AppSpace.s16),
              ToriSpirit(stageIndex: ref.read(appProvider).growth.stageIndex, size: 120, accent: accent, sleeping: _onBreak),
              const SizedBox(height: AppSpace.s24),
              SizedBox(
                width: 240,
                height: 240,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 240,
                      height: 240,
                      child: CircularProgressIndicator(
                        value: progress.clamp(0, 1).toDouble(),
                        strokeWidth: 10,
                        backgroundColor: c.fillStrong,
                        valueColor: AlwaysStoppedAnimation(accent),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(big, style: AppType.title1.copyWith(fontFeatures: const [], fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(sub, style: AppType.label1.copyWith(color: c.labelAlt)),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  SizedBox(width: 120, child: OclButton('그만', ghost: true, onPressed: _abandon)),
                  const SizedBox(width: AppSpace.s10),
                  Expanded(child: OclButton('종료', onPressed: _finish)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWrite(BuildContext context, AppColors c) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text('백지복습', style: AppType.headline2),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('방금 공부한 ${widget.config.subject}에서\n기억나는 내용을 자유롭게 적어봐요.',
                  style: AppType.body1.copyWith(color: c.labelNeutral)),
              const SizedBox(height: AppSpace.s16),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: c.bgElevated,
                    borderRadius: AppRadius.b16,
                    border: Border.all(color: c.lineAlt),
                  ),
                  padding: const EdgeInsets.all(AppSpace.s16),
                  child: TextField(
                    controller: _blankCtrl,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    style: AppType.body1.copyWith(color: c.labelNormal),
                    decoration: const InputDecoration.collapsed(hintText: '배운 개념, 정의, 예시를 떠오르는 대로…'),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.s16),
              if (_analyzing)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpace.s12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: c.accent)),
                      const SizedBox(width: AppSpace.s10),
                      Text('${ref.read(appProvider).growth.name}가 분석하고 있어요…',
                          style: AppType.body2.copyWith(color: c.labelAlt)),
                    ],
                  ),
                )
              else
                OclButton('AI 분석 받기', onPressed: _runBlankAnalysis),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuiz(BuildContext context, AppColors c) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text('문제풀이 기록', style: AppType.headline2),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('${widget.config.subject} · $_focusedMin분 풀이',
                  style: AppType.body1.copyWith(color: c.labelNeutral)),
              const SizedBox(height: AppSpace.s16),
              _quizStepper(c, '맞은 개수', _qCorrect, () => setState(() {
                if (_qCorrect > 0) _qCorrect--;
              }), () => setState(() {
                if (_qCorrect < _qTotal) _qCorrect++;
              })),
              _quizStepper(c, '전체 문제', _qTotal, () => setState(() {
                if (_qTotal > 1) _qTotal--;
                if (_qCorrect > _qTotal) _qCorrect = _qTotal;
              }), () => setState(() => _qTotal++)),
              const Spacer(),
              OclButton('기록하고 결과 보기', onPressed: () => _complete(abandoned: false)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quizStepper(AppColors c, String label, int value, VoidCallback onMinus, VoidCallback onPlus) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppType.body1.copyWith(color: c.labelNeutral)),
          Row(children: [
            _round(c, Icons.remove, onMinus),
            SizedBox(width: 56, child: Text('$value', textAlign: TextAlign.center, style: AppType.headline2)),
            _round(c, Icons.add, onPlus),
          ]),
        ],
      ),
    );
  }

  Widget _round(AppColors c, IconData i, VoidCallback onTap) => Material(
        color: c.fill,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.all(8), child: Icon(i, size: 20, color: c.labelNeutral)),
        ),
      );

  String _fmt(int sec) {
    final h = sec ~/ 3600, m = (sec % 3600) ~/ 60, s = sec % 60;
    final mm = m.toString().padLeft(h > 0 ? 2 : 1, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }
}
