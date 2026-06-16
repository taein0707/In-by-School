import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/live_providers.dart';
import '../../app/presence_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/lesson/lesson.dart';
import '../../domain/lesson/live.dart';
import '../../domain/presence/student_presence.dart';
import '../lesson/live_widgets.dart';

/// TV Mode(P10-4 STEP 3) — 전체화면 발표 뷰. 교사 콘솔의 세션을 따라가며
/// 슬라이드 유형별로 자동 전환(타이머/투표/워드클라우드/아이디어보드/답변/요약).
class TeacherTvModePage extends ConsumerWidget {
  final Lesson lesson;
  const TeacherTvModePage({super.key, required this.lesson});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(lessonSessionProvider(lesson.id)).valueOrNull;
    final slides = lesson.slides;
    final cur = slides.isEmpty ? 0 : (session?.currentSlide ?? 0).clamp(0, slides.length - 1);
    final slide = slides.isEmpty ? null : slides[cur];

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(context, cur, slides.length),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.s32),
                child: Center(child: slide == null ? _white('슬라이드가 없어요') : _stage(context, ref, slide)),
              ),
            ),
            _bottomBar(context, ref),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.small(
        backgroundColor: Colors.white24,
        onPressed: () => context.pop(),
        child: const Icon(Icons.close, color: Colors.white),
      ),
    );
  }

  Widget _topBar(BuildContext context, int cur, int total) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s24, vertical: AppSpace.s12),
      child: Row(children: [
        const Text('● LIVE', style: TextStyle(color: Color(0xFF1ED45A), fontWeight: FontWeight.w800)),
        const SizedBox(width: AppSpace.s16),
        Expanded(
          child: Text(lesson.title.isEmpty ? '실시간 수업' : lesson.title,
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
        ),
        Text('${cur + 1} / $total', style: const TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _bottomBar(BuildContext context, WidgetRef ref) {
    final cid = lesson.classroomId;
    if (cid.isEmpty) return const SizedBox(height: AppSpace.s12);
    final presence = ref.watch(classroomPresenceProvider(cid)).valueOrNull ?? const [];
    int n(StudentPresence s) => presence.where((p) => p.status == s).length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s24, vertical: AppSpace.s16),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _pill('🟢 ${n(StudentPresence.active)}'),
        _pill('🟡 ${n(StudentPresence.idle)}'),
        _pill('🔴 ${n(StudentPresence.away) + n(StudentPresence.offline)}'),
        _pill('📺 ${n(StudentPresence.screenSharing)}'),
      ]),
    );
  }

  Widget _pill(String t) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.s12),
        child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
      );

  Widget _stage(BuildContext context, WidgetRef ref, LessonSlide slide) {
    final responses = ref.watch(lessonResponsesProvider(lesson.id)).valueOrNull ?? const [];
    final forSlide = responses.where((r) => r.slideId == slide.id).map((r) => r.text).toList();

    switch (slide.type) {
      case LessonSlideType.timer:
        final m = (slide.timerSeconds / 60).round();
        return _white('⏱  $m:00', size: 72);
      case LessonSlideType.livePoll:
      case LessonSlideType.multipleChoice:
      case LessonSlideType.ox:
        return _darkCard(context, LiveTallyBars(LiveAggregate.tally(forSlide)));
      case LessonSlideType.wordCloud:
      case LessonSlideType.keyword:
        return _darkCard(context, LiveWordCloud(LiveAggregate.tally(forSlide)));
      case LessonSlideType.ideaBoard:
        final ideas = (ref.watch(lessonIdeasProvider(lesson.id)).valueOrNull ?? const [])
            .where((i) => i.slideId == slide.id)
            .toList();
        final reactionMap =
            LiveAggregate.reactionCounts(ref.watch(lessonReactionsProvider(lesson.id)).valueOrNull ?? const []);
        return _darkCard(context, IdeaBoardView(ideas: ideas, reactions: reactionMap, height: 420));
      default:
        return Column(mainAxisSize: MainAxisSize.min, children: [
          Text(slide.type.label, style: const TextStyle(color: Color(0xFF4D9BFF), fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpace.s20),
          _white(slide.text.isEmpty ? '(내용 없음)' : slide.text, size: 44),
          if (slide.type.hasChoices && slide.choices.isNotEmpty) ...[
            const SizedBox(height: AppSpace.s24),
            for (final ch in slide.choices)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.s8),
                child: Text('· $ch', style: const TextStyle(color: Colors.white70, fontSize: 24)),
              ),
          ],
        ]);
    }
  }

  /// 어두운 TV 배경 위에서 밝은 카드로 집계/보드를 보여준다(공유 위젯 재사용).
  Widget _darkCard(BuildContext context, Widget child) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 900),
      padding: const EdgeInsets.all(AppSpace.s24),
      decoration: BoxDecoration(color: context.c.bg, borderRadius: AppRadius.b24),
      child: child,
    );
  }

  Widget _white(String text, {double size = 36}) => Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white, fontFamily: AppType.family, fontSize: size, fontWeight: FontWeight.w800, height: 1.2),
      );
}
