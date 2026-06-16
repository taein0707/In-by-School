import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/lesson_providers.dart';
import '../../app/teacher_workspace.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/ai/gemini_service.dart';
import '../../domain/lesson/lesson.dart';

/// AI 자동 수업 만들기(P10) — 주제·학년·페이지수·유형·난이도로 수업 전체를 생성.
class AiLessonBuilderPage extends ConsumerStatefulWidget {
  const AiLessonBuilderPage({super.key});

  @override
  ConsumerState<AiLessonBuilderPage> createState() => _AiLessonBuilderPageState();
}

class _AiLessonBuilderPageState extends ConsumerState<AiLessonBuilderPage> {
  final _topic = TextEditingController();
  final _grade = TextEditingController(text: '중학교 2학년');
  int _pages = 10;
  String _difficulty = '보통';
  bool _busy = false;

  static const _typeOptions = [
    LessonSlideType.description,
    LessonSlideType.question,
    LessonSlideType.ideaBoard,
    LessonSlideType.image,
    LessonSlideType.video,
    LessonSlideType.timer,
    LessonSlideType.multipleChoice,
    LessonSlideType.ox,
    LessonSlideType.quiz,
    LessonSlideType.exitTicket,
  ];
  final Set<LessonSlideType> _selected = {
    LessonSlideType.description,
    LessonSlideType.question,
    LessonSlideType.ideaBoard,
    LessonSlideType.timer,
    LessonSlideType.quiz,
    LessonSlideType.exitTicket,
  };

  @override
  void dispose() {
    _topic.dispose();
    _grade.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final topic = _topic.text.trim();
    if (topic.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('주제를 입력해주세요.')));
      return;
    }
    setState(() => _busy = true);
    final ws = ref.read(teacherWorkspaceProvider);
    try {
      final slides = await GeminiService.generateLesson(
        topic: topic,
        grade: _grade.text.trim(),
        pageCount: _pages,
        types: _selected.toList(),
        difficulty: _difficulty,
      );
      final repo = ref.read(lessonRepositoryProvider);
      final lesson = await repo.createLesson(
        title: topic,
        classroomId: ws.classroomId ?? '',
        classroomName: ws.classroomName ?? '',
      );
      final full = lesson.copyWith(title: topic, slides: slides);
      await repo.saveLesson(full);
      if (mounted) context.pushReplacement('/t/lessons/edit', extra: full);
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('생성에 실패했어요. 잠시 후 다시 시도해주세요.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => context.pop()),
        title: Text('AI 수업 만들기', style: AppType.headline2),
      ),
      body: SafeArea(
        child: _busy
            ? Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  CircularProgressIndicator(color: c.accent),
                  const SizedBox(height: AppSpace.s16),
                  Text('AI가 수업을 만들고 있어요…', style: AppType.body1.copyWith(color: c.labelNeutral)),
                ]),
              )
            : ListView(
                padding: const EdgeInsets.all(AppSpace.s20),
                children: [
                  _label(c, '주제'),
                  _field(c, _topic, '예) 광합성'),
                  const SizedBox(height: AppSpace.s16),
                  _label(c, '학년'),
                  _field(c, _grade, '예) 중학교 2학년'),
                  const SizedBox(height: AppSpace.s16),
                  _label(c, '페이지 수 · $_pages장'),
                  Slider(
                    value: _pages.toDouble(),
                    min: 3,
                    max: 20,
                    divisions: 17,
                    activeColor: c.accent,
                    label: '$_pages',
                    onChanged: (v) => setState(() => _pages = v.round()),
                  ),
                  const SizedBox(height: AppSpace.s8),
                  _label(c, '난이도'),
                  Row(children: [
                    for (final d in const ['쉬움', '보통', '어려움']) ...[
                      Expanded(child: _seg(c, d)),
                      if (d != '어려움') const SizedBox(width: AppSpace.s8),
                    ],
                  ]),
                  const SizedBox(height: AppSpace.s16),
                  _label(c, '포함할 슬라이드 유형'),
                  Wrap(
                    spacing: AppSpace.s8,
                    runSpacing: AppSpace.s8,
                    children: [
                      for (final t in _typeOptions)
                        FilterChip(
                          label: Text(t.label, style: AppType.label2.copyWith(color: _selected.contains(t) ? c.accent : c.labelNeutral)),
                          selected: _selected.contains(t),
                          selectedColor: c.accentSoft,
                          checkmarkColor: c.accent,
                          onSelected: (on) => setState(() => on ? _selected.add(t) : _selected.remove(t)),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.s24),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: c.accent, minimumSize: const Size.fromHeight(52)),
                    onPressed: _generate,
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('AI로 수업 생성'),
                  ),
                  const SizedBox(height: AppSpace.s8),
                  Text('생성 후 편집 화면에서 슬라이드를 추가·수정하거나 “AI 수정”으로 바꿀 수 있어요.',
                      style: AppType.caption1.copyWith(color: c.labelAssistive)),
                ],
              ),
      ),
    );
  }

  Widget _seg(AppColors c, String d) {
    final on = _difficulty == d;
    return InkWell(
      borderRadius: AppRadius.b14,
      onTap: () => setState(() => _difficulty = d),
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? c.accent : c.bgElevated,
          borderRadius: AppRadius.b14,
          border: Border.all(color: on ? c.accent : c.lineAlt),
        ),
        child: Text(d, style: AppType.label1.copyWith(color: on ? Colors.white : c.labelAlt)),
      ),
    );
  }

  Widget _label(AppColors c, String t) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.s8),
        child: Text(t, style: AppType.label1.copyWith(color: c.labelNeutral)),
      );

  Widget _field(AppColors c, TextEditingController ctrl, String hint) => TextField(
        controller: ctrl,
        style: AppType.body1.copyWith(color: c.labelNormal),
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: c.bgElevated,
          enabledBorder: OutlineInputBorder(borderRadius: AppRadius.b14, borderSide: BorderSide(color: c.lineAlt)),
          focusedBorder: OutlineInputBorder(borderRadius: AppRadius.b14, borderSide: BorderSide(color: c.accent, width: 2)),
          contentPadding: const EdgeInsets.all(AppSpace.s16),
        ),
      );
}
