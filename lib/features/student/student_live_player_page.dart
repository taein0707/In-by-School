import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/account_providers.dart';
import '../../app/lesson_providers.dart';
import '../../app/live_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/lesson/lesson.dart';
import '../../domain/lesson/live.dart';
import '../lesson/live_widgets.dart';

/// 학생 라이브 플레이어(P10-2) — 교실의 진행 중 세션을 구독해 교사를 따라간다.
class StudentLivePlayerPage extends ConsumerStatefulWidget {
  final String classroomId;
  const StudentLivePlayerPage({super.key, required this.classroomId});

  @override
  ConsumerState<StudentLivePlayerPage> createState() => _StudentLivePlayerPageState();
}

class _StudentLivePlayerPageState extends ConsumerState<StudentLivePlayerPage> {
  final _input = TextEditingController();
  int _localIndex = 0;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final session = ref.watch(liveSessionForClassroomProvider(widget.classroomId)).valueOrNull;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => context.pop()),
        title: Text('실시간 수업', style: AppType.headline2),
      ),
      body: SafeArea(
        child: session == null || !session.live
            ? _idle(c)
            : _live(c, session),
      ),
    );
  }

  Widget _idle(AppColors c) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.cast_outlined, size: 48, color: c.labelAssistive),
            const SizedBox(height: AppSpace.s12),
            Text('진행 중인 수업이 없어요.', style: AppType.body1.copyWith(color: c.labelAlt)),
            const SizedBox(height: 4),
            Text('선생님이 수업을 시작하면 자동으로 표시돼요.', style: AppType.body2.copyWith(color: c.labelAssistive)),
          ]),
        ),
      );

  Widget _live(AppColors c, LessonSession session) {
    final lesson = ref.watch(lessonByIdProvider(session.lessonId)).valueOrNull;
    if (lesson == null || lesson.slides.isEmpty) {
      return Center(child: Text('수업을 불러오는 중…', style: AppType.body2.copyWith(color: c.labelAlt)));
    }
    final slides = lesson.slides;
    // 자유 이동이 꺼져 있으면 교사 슬라이드에 고정.
    final index = session.allowFreeMove ? _localIndex.clamp(0, slides.length - 1) : session.currentSlide.clamp(0, slides.length - 1);
    final slide = slides[index];

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16, vertical: AppSpace.s8),
          color: c.bgAlt,
          child: Row(children: [
            Text('${index + 1} / ${slides.length}', style: AppType.label1.copyWith(color: c.labelNeutral)),
            const SizedBox(width: AppSpace.s8),
            if (session.paused)
              Text('· 일시정지', style: AppType.caption1.copyWith(color: c.cautionary))
            else if (!session.allowFreeMove)
              Text('· 선생님을 따라가는 중', style: AppType.caption1.copyWith(color: c.accent)),
            IconButton(
              tooltip: '익명 질문',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.live_help_outlined),
              onPressed: () => _askQuestion(session),
            ),
            if (session.allowFreeMove) ...[
              IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.chevron_left), onPressed: () => setState(() => _localIndex = (index - 1).clamp(0, slides.length - 1))),
              IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.chevron_right), onPressed: () => setState(() => _localIndex = (index + 1).clamp(0, slides.length - 1))),
            ],
          ]),
        ),
        Divider(height: 1, color: c.lineAlt),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpace.s20),
            children: [
              _stage(c, session, slide),
              const SizedBox(height: AppSpace.s20),
              _input2(c, session, slide),
              ..._aggregate(c, session, slide),
              ..._board(c, session, slide),
            ],
          ),
        ),
      ],
    );
  }

  /// 슬라이드 무대 + 교사 포인터 오버레이(STEP 2).
  Widget _stage(AppColors c, LessonSession session, LessonSlide slide) {
    final pointer = ref.watch(lessonPointerProvider(session.lessonId)).valueOrNull;
    return SizedBox(
      height: 300,
      child: LivePointerLayer(
        pointer: pointer,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          padding: const EdgeInsets.all(AppSpace.s20),
          decoration: BoxDecoration(color: c.bgElevated, borderRadius: AppRadius.b16, border: Border.all(color: c.lineAlt)),
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(slide.type.label, style: AppType.caption1.copyWith(color: c.accent, fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpace.s8),
              Text(slide.text.isEmpty ? '(내용 없음)' : slide.text, style: AppType.title2.copyWith(color: c.labelStrong)),
              if (slide.mediaUrl.isNotEmpty) ...[
                const SizedBox(height: AppSpace.s8),
                Text(slide.mediaUrl, style: AppType.body2.copyWith(color: c.accent)),
              ],
            ]),
          ),
        ),
      ),
    );
  }

  /// 학생용 라이브 집계(워드클라우드/투표) — 교사가 쓴 doc 을 구독해 표시(STEP 1).
  List<Widget> _aggregate(AppColors c, LessonSession session, LessonSlide slide) {
    final coll = tallyCollectionFor(slide.type);
    if (coll == null) return const [];
    final counts = ref.watch(liveTallyProvider((coll: coll, lessonId: session.lessonId, slideId: slide.id))).valueOrNull ?? const {};
    final isCloud = coll == 'lessonWordCloud';
    return [
      const SizedBox(height: AppSpace.s24),
      Text(isCloud ? '실시간 워드클라우드' : '실시간 결과', style: AppType.label1.copyWith(color: c.labelNeutral)),
      const SizedBox(height: AppSpace.s8),
      isCloud ? LiveWordCloud(counts) : LiveTallyBars(counts),
    ];
  }

  /// 아이디어보드 슬라이드: 교사가 정리하는 보드를 실시간 표시(읽기 전용) + 좋아요(STEP 1·4).
  List<Widget> _board(AppColors c, LessonSession session, LessonSlide slide) {
    if (slide.type != LessonSlideType.ideaBoard) return const [];
    final ideas = (ref.watch(lessonIdeasProvider(session.lessonId)).valueOrNull ?? const [])
        .where((i) => i.slideId == slide.id)
        .toList();
    final reactionMap =
        LiveAggregate.reactionCounts(ref.watch(lessonReactionsProvider(session.lessonId)).valueOrNull ?? const []);
    final uid = ref.watch(authStateProvider).valueOrNull?.uid;
    return [
      const SizedBox(height: AppSpace.s24),
      Text('실시간 보드', style: AppType.label1.copyWith(color: c.labelNeutral)),
      const SizedBox(height: AppSpace.s8),
      IdeaBoardView(
        ideas: ideas,
        reactions: reactionMap,
        onReact: uid == null
            ? null
            : (target, emoji) => ref
                .read(liveLessonRepositoryProvider)
                .toggleReaction(lessonId: session.lessonId, targetId: target, emoji: emoji, studentUid: uid),
      ),
    ];
  }

  Future<void> _askQuestion(LessonSession session) async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    final ctrl = TextEditingController();
    final c = context.c;
    final text = await showDialog<String>(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: c.bgElevated,
        title: const Text('익명 질문'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 2,
          decoration: const InputDecoration(hintText: '예) 이 부분이 이해가 안 돼요'),
          onSubmitted: (v) => Navigator.pop(dctx, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dctx), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(dctx, ctrl.text.trim()), child: const Text('보내기')),
        ],
      ),
    );
    if (text == null || text.isEmpty) return;
    await ref.read(liveLessonRepositoryProvider).addQuestion(LessonQuestion(
          id: '',
          lessonId: session.lessonId,
          teacherUid: session.teacherUid,
          studentUid: uid,
          text: text,
          anonymous: true,
          createdAt: DateTime.now(),
        ));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('선생님께 질문을 보냈어요.')));
  }

  Widget _input2(AppColors c, LessonSession session, LessonSlide slide) {
    final uid = ref.watch(authStateProvider).valueOrNull?.uid;
    final name = ref.watch(currentProfileProvider).valueOrNull?.displayName ?? '';
    if (uid == null) return const SizedBox.shrink();

    LessonResponse base(ResponseKind kind, String text) => LessonResponse(
          id: '',
          lessonId: session.lessonId,
          slideId: slide.id,
          studentUid: uid,
          teacherUid: session.teacherUid,
          studentName: name,
          kind: kind,
          text: text,
          createdAt: DateTime.now(),
        );

    final repo = ref.read(liveLessonRepositoryProvider);

    // 선택/투표형 — 버튼.
    if (slide.type == LessonSlideType.multipleChoice || slide.type == LessonSlideType.ox || slide.type == LessonSlideType.livePoll) {
      final isVote = slide.type == LessonSlideType.livePoll;
      final options = slide.choices.isNotEmpty
          ? slide.choices
          : (slide.type == LessonSlideType.ox ? const ['O', 'X'] : const ['찬성', '반대', '기권']);
      return Wrap(
        spacing: AppSpace.s8,
        runSpacing: AppSpace.s8,
        children: [
          for (final opt in options)
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: c.accentSoft, foregroundColor: c.accent),
              onPressed: () async {
                await repo.upsertResponse(base(isVote ? ResponseKind.vote : ResponseKind.choice, opt));
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('‘$opt’ 제출!')));
              },
              child: Text(opt),
            ),
        ],
      );
    }

    // 입력형 — 텍스트.
    final isIdea = slide.type == LessonSlideType.ideaBoard;
    final isText = isIdea ||
        slide.type == LessonSlideType.shortAnswer ||
        slide.type == LessonSlideType.longAnswer ||
        slide.type == LessonSlideType.keyword ||
        slide.type == LessonSlideType.question ||
        slide.type == LessonSlideType.wordCloud ||
        slide.type == LessonSlideType.exitTicket ||
        slide.type == LessonSlideType.anonymousQuestion;
    if (!isText) {
      return Text('선생님 화면을 따라가요.', style: AppType.body2.copyWith(color: c.labelAlt));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(
        controller: _input,
        maxLines: slide.type == LessonSlideType.longAnswer ? 4 : 1,
        style: AppType.body1.copyWith(color: c.labelNormal),
        decoration: InputDecoration(
          hintText: isIdea ? '떠오르는 것을 적어보세요' : '답변을 입력하세요',
          filled: true,
          fillColor: c.bgElevated,
          enabledBorder: OutlineInputBorder(borderRadius: AppRadius.b14, borderSide: BorderSide(color: c.lineAlt)),
          focusedBorder: OutlineInputBorder(borderRadius: AppRadius.b14, borderSide: BorderSide(color: c.accent, width: 2)),
          contentPadding: const EdgeInsets.all(AppSpace.s16),
        ),
      ),
      const SizedBox(height: AppSpace.s12),
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: c.accent, minimumSize: const Size.fromHeight(48)),
        onPressed: () async {
          final t = _input.text.trim();
          if (t.isEmpty) return;
          if (isIdea) {
            // 아이디어보드는 lessonIdeas(포스트잇)로 — 겹치지 않게 위치를 분산.
            final n = (ref.read(lessonIdeasProvider(session.lessonId)).valueOrNull ?? const [])
                .where((i) => i.slideId == slide.id)
                .length;
            await repo.addIdea(LessonIdea(
              id: '',
              lessonId: session.lessonId,
              slideId: slide.id,
              teacherUid: session.teacherUid,
              authorUid: uid,
              authorName: name,
              text: t,
              x: 0.18 + 0.64 * ((n * 0.37) % 1.0),
              y: 0.18 + 0.64 * ((n * 0.61) % 1.0),
              createdAt: DateTime.now(),
            ));
          } else {
            await repo.upsertResponse(base(ResponseKind.text, t));
          }
          _input.clear();
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('제출했어요!')));
        },
        child: Text(isIdea ? '추가' : '제출'),
      ),
    ]);
  }
}
