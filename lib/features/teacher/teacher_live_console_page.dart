import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/account_providers.dart';
import '../../app/lesson_providers.dart';
import '../../app/live_providers.dart';
import '../../app/presence_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/ai/gemini_service.dart';
import '../../data/firebase/live_lesson_repository.dart';
import '../../domain/lesson/lesson.dart';
import '../../domain/lesson/live.dart';
import '../../domain/presence/student_presence.dart';
import '../lesson/live_widgets.dart';

/// Teacher Live Mode 콘솔(P10-2) — 슬라이드를 넘기면 학생이 동시 이동.
class TeacherLiveConsolePage extends ConsumerStatefulWidget {
  final Lesson lesson;
  const TeacherLiveConsolePage({super.key, required this.lesson});

  @override
  ConsumerState<TeacherLiveConsolePage> createState() => _TeacherLiveConsolePageState();
}

class _TeacherLiveConsolePageState extends ConsumerState<TeacherLiveConsolePage> {
  late Lesson _lesson;
  String? _summary;
  bool _summarizing = false;

  // Teacher Pointer(P10-3)
  bool _pointerOn = false;
  String _pointerColor = 'yellow';
  final GlobalKey _slideKey = GlobalKey();
  double _lastX = 0.5, _lastY = 0.5;

  @override
  void initState() {
    super.initState();
    _lesson = widget.lesson;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(liveLessonRepositoryProvider).startSession(
            lessonId: _lesson.id,
            classroomId: _lesson.classroomId,
          );
    });
  }

  LiveLessonRepository get _repo => ref.read(liveLessonRepositoryProvider);

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final session = ref.watch(lessonSessionProvider(_lesson.id)).valueOrNull;
    final responses = ref.watch(lessonResponsesProvider(_lesson.id)).valueOrNull ?? const [];
    final pointer = ref.watch(lessonPointerProvider(_lesson.id)).valueOrNull;
    final ideas = ref.watch(lessonIdeasProvider(_lesson.id)).valueOrNull ?? const [];
    final reactionMap = LiveAggregate.reactionCounts(ref.watch(lessonReactionsProvider(_lesson.id)).valueOrNull ?? const []);
    final pending = (ref.watch(lessonQuestionsProvider(_lesson.id)).valueOrNull ?? const [])
        .where((q) => !q.approved)
        .length;
    // 응답·슬라이드가 바뀌면 학생용 집계 doc 을 갱신(STEP 1).
    ref.listen(lessonResponsesProvider(_lesson.id), (_, __) => _syncAggregate());
    ref.listen(lessonSessionProvider(_lesson.id), (_, __) => _syncAggregate());
    final slides = _lesson.slides;
    final cur = slides.isEmpty ? 0 : (session?.currentSlide ?? 0).clamp(0, slides.length - 1);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(_lesson.title.isEmpty ? '실시간 수업' : _lesson.title, style: AppType.headline2),
        actions: [
          IconButton(
            tooltip: 'TV 화면',
            onPressed: () => context.push('/t/lessons/tv', extra: _lesson),
            icon: const Icon(Icons.tv_outlined),
          ),
          IconButton(
            tooltip: '익명 질문',
            onPressed: _questionsSheet,
            icon: Badge(
              isLabelVisible: pending > 0,
              label: Text('$pending'),
              child: const Icon(Icons.live_help_outlined),
            ),
          ),
          TextButton.icon(
            onPressed: () => _endWithSummary(responses),
            icon: Icon(Icons.stop_circle_outlined, size: 18, color: c.negative),
            label: Text('종료', style: AppType.label1.copyWith(color: c.negative)),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _liveBar(c, session, slides.length, cur, responses.length),
            Divider(height: 1, color: c.lineAlt),
            Expanded(
              child: slides.isEmpty
                  ? Center(child: Text('슬라이드가 없어요. 편집에서 추가해주세요.', style: AppType.body2.copyWith(color: c.labelAlt)))
                  : ListView(
                      padding: const EdgeInsets.all(AppSpace.s20),
                      children: [
                        _liveSlide(c, slides[cur], cur, pointer),
                        const SizedBox(height: AppSpace.s16),
                        _panel(c, slides[cur], responses, ideas, reactionMap),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// 포인터를 겹쳐 그릴 수 있는 고정 높이 슬라이드 영역.
  Widget _liveSlide(AppColors c, LessonSlide s, int i, LessonPointer? pointer) {
    return SizedBox(
      height: 300,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (e) => _movePointer(e.position, true),
        onPointerMove: (e) => _movePointer(e.position, true),
        onPointerUp: (e) {
          if (_pointerOn) {
            _repo.setPointer(lessonId: _lesson.id, x: _lastX, y: _lastY, color: _pointerColor, active: false);
          }
        },
        child: LivePointerLayer(
          pointer: pointer,
          child: Container(
            key: _slideKey,
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(color: c.bgElevated, borderRadius: AppRadius.b16, border: Border.all(color: c.lineAlt)),
            padding: const EdgeInsets.all(AppSpace.s20),
            child: SingleChildScrollView(child: _slideBody(c, s)),
          ),
        ),
      ),
    );
  }

  void _movePointer(Offset global, bool active) {
    if (!_pointerOn) return;
    final box = _slideKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(global);
    _lastX = (local.dx / box.size.width).clamp(0.0, 1.0);
    _lastY = (local.dy / box.size.height).clamp(0.0, 1.0);
    _repo.setPointer(lessonId: _lesson.id, x: _lastX, y: _lastY, color: _pointerColor, active: active);
  }

  // ---- 상단 고정 라이브 바 ----
  Widget _liveBar(AppColors c, LessonSession? s, int total, int cur, int responseCount) {
    final live = s?.live ?? false;
    final paused = s?.paused ?? false;
    final free = s?.allowFreeMove ?? false;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16, vertical: AppSpace.s10),
      color: c.bgAlt,
      child: Column(
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.s8, vertical: 2),
              decoration: BoxDecoration(color: (live ? c.positive : c.labelAssistive).withValues(alpha: 0.16), borderRadius: AppRadius.bFull),
              child: Text(live ? '● LIVE' : '대기', style: AppType.caption1.copyWith(color: live ? c.positive : c.labelAlt, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: AppSpace.s12),
            Text('${cur + 1} / $total', style: AppType.headline2.copyWith(color: c.labelStrong)),
            const Spacer(),
            _participation(c),
          ]),
          const SizedBox(height: AppSpace.s8),
          Row(children: [
            _ctrl(c, Icons.chevron_left, '이전', () => _repo.goToSlide(_lesson.id, (cur - 1).clamp(0, total - 1))),
            _ctrl(c, paused ? Icons.play_arrow : Icons.pause, paused ? '재개' : '일시정지', () => _repo.setPaused(_lesson.id, !paused)),
            _ctrl(c, Icons.chevron_right, '다음', () => _repo.goToSlide(_lesson.id, (cur + 1).clamp(0, total - 1))),
            const SizedBox(width: AppSpace.s4),
            IconButton.filledTonal(
              tooltip: _pointerOn ? '포인터 끄기' : '교사 포인터',
              isSelected: _pointerOn,
              onPressed: () => setState(() => _pointerOn = !_pointerOn),
              icon: const Icon(Icons.my_location),
              color: _pointerOn ? pointerColor(_pointerColor) : c.accent,
            ),
            const Spacer(),
            Text('자유 이동', style: AppType.label2.copyWith(color: c.labelAlt)),
            Switch(value: free, activeColor: c.accent, onChanged: (v) => _repo.setAllowFreeMove(_lesson.id, v)),
          ]),
          if (_pointerOn)
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.s8),
              child: Row(children: [
                Text('포인터 색 · 슬라이드를 누르거나 드래그하세요', style: AppType.caption1.copyWith(color: c.labelAlt)),
                const Spacer(),
                for (final col in const ['yellow', 'red', 'blue', 'laser']) _colorDot(col),
              ]),
            ),
        ],
      ),
    );
  }

  Widget _colorDot(String col) {
    final on = _pointerColor == col;
    return Padding(
      padding: const EdgeInsets.only(left: AppSpace.s8),
      child: InkWell(
        onTap: () => setState(() => _pointerColor = col),
        customBorder: const CircleBorder(),
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: pointerColor(col),
            shape: BoxShape.circle,
            border: Border.all(color: on ? context.c.labelStrong : Colors.transparent, width: 2),
          ),
        ),
      ),
    );
  }

  // ---- STEP 1: 학생용 집계 doc 갱신 ----
  void _syncAggregate() {
    final session = ref.read(lessonSessionProvider(_lesson.id)).valueOrNull;
    final rs = ref.read(lessonResponsesProvider(_lesson.id)).valueOrNull;
    if (session == null || rs == null || _lesson.slides.isEmpty) return;
    final idx = session.currentSlide.clamp(0, _lesson.slides.length - 1);
    final slide = _lesson.slides[idx];
    final coll = tallyCollectionFor(slide.type);
    if (coll == null) return;
    final counts = LiveAggregate.tally(rs.where((r) => r.slideId == slide.id).map((r) => r.text));
    _repo.writeTally(collection: coll, lessonId: _lesson.id, slideId: slide.id, counts: counts);
  }

  // ---- STEP 6: 익명 질문 승인/거부 ----
  void _questionsSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.c.bgElevated,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: AppRadius.r24)),
      builder: (sc) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (_, scroll) => Consumer(builder: (ctx, ref2, __) {
          final c = ctx.c;
          final qs = ref2.watch(lessonQuestionsProvider(_lesson.id)).valueOrNull ?? const [];
          return ListView(
            controller: scroll,
            padding: const EdgeInsets.all(AppSpace.s20),
            children: [
              Text('익명 질문', style: AppType.title3),
              const SizedBox(height: AppSpace.s12),
              if (qs.isEmpty) Text('아직 질문이 없어요.', style: AppType.body2.copyWith(color: c.labelAlt)),
              for (final q in qs)
                Container(
                  margin: const EdgeInsets.only(bottom: AppSpace.s8),
                  padding: const EdgeInsets.all(AppSpace.s12),
                  decoration: BoxDecoration(
                    color: q.approved ? c.accentSoft : c.bg,
                    borderRadius: AppRadius.b12,
                    border: Border.all(color: c.lineAlt),
                  ),
                  child: Row(children: [
                    Expanded(child: Text(q.text, style: AppType.body2.copyWith(color: c.labelNormal))),
                    if (q.approved)
                      Text('공개됨', style: AppType.caption1.copyWith(color: c.accent))
                    else ...[
                      TextButton(onPressed: () => _repo.approveQuestion(q.id), child: const Text('승인')),
                      IconButton(icon: Icon(Icons.delete_outline, size: 18, color: c.negative), onPressed: () => _repo.deleteQuestion(q.id)),
                    ],
                  ]),
                ),
            ],
          );
        }),
      ),
    );
  }

  // ---- STEP 8: 수업 종료 + AI 요약 ----
  Future<void> _endWithSummary(List<LessonResponse> responses) async {
    final texts = responses.map((r) => r.text).where((t) => t.trim().isNotEmpty).toList();
    final summary = texts.isEmpty ? '오늘 수업이 끝났어요. 수고했어요!' : await GeminiService.summarizeResponses(texts);
    if (!mounted) return;
    final go = await showDialog<bool>(
      context: context,
      builder: (dctx) {
        final c = dctx.c;
        return AlertDialog(
          backgroundColor: c.bgElevated,
          title: const Text('오늘의 수업 요약'),
          content: Text(summary, style: AppType.body2.copyWith(color: c.labelNeutral)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dctx, false), child: const Text('계속 진행')),
            TextButton(onPressed: () => Navigator.pop(dctx, true), child: const Text('수업 종료')),
          ],
        );
      },
    );
    if (go == true) {
      await _repo.endSession(_lesson.id);
      if (mounted) context.pop();
    }
  }

  Widget _participation(AppColors c) {
    final cid = _lesson.classroomId;
    if (cid.isEmpty) return const SizedBox.shrink();
    final presence = ref.watch(classroomPresenceProvider(cid)).valueOrNull ?? const [];
    int n(StudentPresence s) => presence.where((p) => p.status == s).length;
    return Wrap(spacing: AppSpace.s8, children: [
      Text('🟢${n(StudentPresence.active)}', style: AppType.caption1.copyWith(color: c.positive)),
      Text('🟡${n(StudentPresence.idle)}', style: AppType.caption1.copyWith(color: c.cautionary)),
      Text('🔴${n(StudentPresence.away) + n(StudentPresence.offline)}', style: AppType.caption1.copyWith(color: c.negative)),
      Text('📺${n(StudentPresence.screenSharing)}', style: AppType.caption1.copyWith(color: c.accent)),
    ]);
  }

  Widget _ctrl(AppColors c, IconData icon, String tip, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: AppSpace.s4),
        child: IconButton.filledTonal(tooltip: tip, onPressed: onTap, icon: Icon(icon), color: c.accent),
      );

  Widget _slideBody(AppColors c, LessonSlide s) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(s.type.label, style: AppType.caption1.copyWith(color: c.accent, fontWeight: FontWeight.w700)),
      const SizedBox(height: AppSpace.s8),
      Text(s.text.isEmpty ? '(내용 없음)' : s.text, style: AppType.title3.copyWith(color: c.labelStrong)),
      if (s.type.hasChoices && s.choices.isNotEmpty) ...[
        const SizedBox(height: AppSpace.s8),
        Text(s.choices.join('   ·   '), style: AppType.body2.copyWith(color: c.labelAlt)),
      ],
      if (s.mediaUrl.isNotEmpty) ...[
        const SizedBox(height: AppSpace.s8),
        Text(s.mediaUrl, style: AppType.body2.copyWith(color: c.accent)),
      ],
    ]);
  }

  // ---- 슬라이드 유형별 라이브 패널 ----
  Widget _panel(AppColors c, LessonSlide s, List<LessonResponse> all, List<LessonIdea> ideas, Map<String, Map<String, int>> reactionMap) {
    final forSlide = all.where((r) => r.slideId == s.id).toList();
    final texts = forSlide.map((r) => r.text).toList();
    switch (s.type) {
      case LessonSlideType.ideaBoard:
        final slideIdeas = ideas.where((i) => i.slideId == s.id).toList();
        return IdeaBoardView(
          ideas: slideIdeas,
          reactions: reactionMap,
          onReact: (target, emoji) => _react(target, emoji),
          onMove: (id, x, y) => _repo.updateIdea(id, {'x': x, 'y': y}),
          onTapIdea: _ideaMenu,
        );
      case LessonSlideType.livePoll:
      case LessonSlideType.multipleChoice:
      case LessonSlideType.ox:
        return _tallyBars(texts);
      case LessonSlideType.wordCloud:
      case LessonSlideType.keyword:
        return _wordCloud(texts);
      case LessonSlideType.shortAnswer:
      case LessonSlideType.longAnswer:
      case LessonSlideType.question:
      case LessonSlideType.exitTicket:
      case LessonSlideType.aiSummary:
      case LessonSlideType.studentSlide:
        return _answers(c, forSlide);
      default:
        return _empty(c, '실시간 응답 ${forSlide.length}개');
    }
  }

  void _react(String targetId, String emoji) {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    _repo.toggleReaction(lessonId: _lesson.id, targetId: targetId, emoji: emoji, studentUid: uid);
  }

  // ---- STEP 1: 포스트잇 메뉴(색상/잠금/복제/그룹/삭제) ----
  void _ideaMenu(LessonIdea idea) {
    final c = context.c;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.bgElevated,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: AppRadius.r24)),
      builder: (sc) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(idea.text, style: AppType.headline2.copyWith(color: c.labelStrong), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: AppSpace.s16),
            Row(children: [
              Text('색상', style: AppType.label2.copyWith(color: c.labelAlt)),
              const SizedBox(width: AppSpace.s12),
              for (final col in kPostitColors)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpace.s8),
                  child: InkWell(
                    onTap: () {
                      _repo.updateIdea(idea.id, {'color': col});
                      Navigator.pop(sc);
                    },
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 26, height: 26,
                      decoration: BoxDecoration(
                        color: postitColor(col),
                        shape: BoxShape.circle,
                        border: Border.all(color: idea.color == col ? c.labelStrong : c.lineAlt, width: 2),
                      ),
                    ),
                  ),
                ),
            ]),
            const SizedBox(height: AppSpace.s8),
            ListTile(
              dense: true,
              leading: Icon(idea.locked ? Icons.lock_open : Icons.lock_outline, color: c.labelNeutral),
              title: Text(idea.locked ? '잠금 해제' : '잠금', style: AppType.body2.copyWith(color: c.labelNeutral)),
              onTap: () {
                _repo.updateIdea(idea.id, {'locked': !idea.locked});
                Navigator.pop(sc);
              },
            ),
            ListTile(
              dense: true,
              leading: Icon(idea.groupId.isEmpty ? Icons.workspaces_outline : Icons.workspaces, color: c.labelNeutral),
              title: Text(idea.groupId.isEmpty ? '그룹으로 묶기' : '그룹 해제', style: AppType.body2.copyWith(color: c.labelNeutral)),
              onTap: () {
                _repo.updateIdea(idea.id, {'groupId': idea.groupId.isEmpty ? idea.slideId : ''});
                Navigator.pop(sc);
              },
            ),
            ListTile(
              dense: true,
              leading: Icon(Icons.copy_outlined, color: c.labelNeutral),
              title: Text('복제', style: AppType.body2.copyWith(color: c.labelNeutral)),
              onTap: () {
                _repo.addIdea(LessonIdea(
                  id: '', lessonId: idea.lessonId, slideId: idea.slideId, teacherUid: idea.teacherUid,
                  authorUid: idea.authorUid, authorName: idea.authorName, text: idea.text, color: idea.color,
                  x: (idea.x + 0.06).clamp(0.0, 1.0), y: (idea.y + 0.06).clamp(0.0, 1.0),
                ));
                Navigator.pop(sc);
              },
            ),
            ListTile(
              dense: true,
              leading: Icon(Icons.delete_outline, color: c.negative),
              title: Text('삭제', style: AppType.body2.copyWith(color: c.negative)),
              onTap: () {
                _repo.deleteIdea(idea.id);
                Navigator.pop(sc);
              },
            ),
          ]),
        ),
      ),
    );
  }

  // 교사 패널도 학생과 동일한 공유 위젯으로 렌더(STEP 1) — 집계 doc 은 _syncAggregate 가 기록.
  Widget _tallyBars(List<String> texts) => LiveTallyBars(LiveAggregate.tally(texts));
  Widget _wordCloud(List<String> texts) => LiveWordCloud(LiveAggregate.tally(texts));

  Widget _answers(AppColors c, List<LessonResponse> rs) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Text('응답 ${rs.length}개', style: AppType.label1.copyWith(color: c.labelNeutral)),
        const Spacer(),
        TextButton.icon(
          onPressed: _summarizing || rs.isEmpty ? null : () => _summarize(rs),
          icon: _summarizing
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.auto_awesome, size: 16),
          label: Text(_summary == null ? 'AI 요약' : '다시 생성'),
        ),
      ]),
      if (_summary != null)
        Container(
          margin: const EdgeInsets.only(bottom: AppSpace.s12),
          padding: const EdgeInsets.all(AppSpace.s16),
          decoration: BoxDecoration(color: c.accentSoft, borderRadius: AppRadius.b14),
          child: Text(_summary!, style: AppType.body2.copyWith(color: c.labelNeutral)),
        ),
      for (final r in rs)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpace.s8),
          child: Container(
            padding: const EdgeInsets.all(AppSpace.s12),
            decoration: BoxDecoration(color: c.bgElevated, borderRadius: AppRadius.b12, border: Border.all(color: c.lineAlt)),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.studentName.isEmpty ? '학생' : r.studentName, style: AppType.caption1.copyWith(color: c.labelAlt)),
                  Text(r.text, style: AppType.body1.copyWith(color: c.labelNormal)),
                ]),
              ),
              IconButton(
                tooltip: '슬라이드로 만들기',
                icon: Icon(Icons.add_to_photos_outlined, size: 18, color: c.accent),
                onPressed: () => _answerToSlide(r),
              ),
            ]),
          ),
        ),
    ]);
  }

  Future<void> _summarize(List<LessonResponse> rs) async {
    setState(() => _summarizing = true);
    final text = await GeminiService.summarizeResponses(rs.map((r) => r.text).toList());
    if (mounted) {
      setState(() {
        _summary = text;
        _summarizing = false;
      });
    }
  }

  Future<void> _answerToSlide(LessonResponse r) async {
    final slide = LessonSlide(
      id: 's${DateTime.now().microsecondsSinceEpoch}',
      type: LessonSlideType.studentSlide,
      text: '우수 답변 · ${r.studentName.isEmpty ? '학생' : r.studentName}\n${r.text}',
    );
    final updated = _lesson.copyWith(slides: [..._lesson.slides, slide]);
    try {
      await ref.read(lessonRepositoryProvider).saveLesson(updated);
      if (mounted) {
        setState(() => _lesson = updated);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('답변을 슬라이드로 추가했어요.')));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('추가하지 못했어요.')));
    }
  }

  Widget _empty(AppColors c, String text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpace.s24),
        decoration: BoxDecoration(color: c.bgAlt, borderRadius: AppRadius.b14),
        child: Center(child: Text(text, style: AppType.body2.copyWith(color: c.labelAlt))),
      );
}
