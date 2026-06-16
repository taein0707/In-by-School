import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/lesson_providers.dart';
import '../../app/teacher_workspace.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/lesson/lesson.dart';
import '../../shared/widgets/lnb_tabs.dart';

/// 교사 수업 허브(P9-2 #6) — 슬라이드 기반 수업 목록 + 생성. LNB 로 유형을 나눈다.
class TeacherLessonsPage extends ConsumerStatefulWidget {
  const TeacherLessonsPage({super.key});

  @override
  ConsumerState<TeacherLessonsPage> createState() => _TeacherLessonsPageState();
}

class _TeacherLessonsPageState extends ConsumerState<TeacherLessonsPage> {
  static const _tabs = ['전체', '학습지', '실시간수업', '아이디어보드', '퀴즈'];
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final ws = ref.watch(teacherWorkspaceProvider);
    final lessons = ref.watch(teacherLessonsProvider).valueOrNull ?? const [];

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: AppSpace.s20,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text('수업', style: AppType.headline1),
          Text(ws.title, style: AppType.caption1.copyWith(color: c.accent)),
        ]),
        actions: [
          IconButton(
            tooltip: 'AI 수업 만들기',
            icon: const Icon(Icons.auto_awesome),
            onPressed: () => context.push('/t/lessons/ai'),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: LnbTabs(labels: _tabs, selected: _tab, onSelected: (i) => setState(() => _tab = i)),
        ),
      ),
      floatingActionButton: _tab == 1
          ? null
          : FloatingActionButton.extended(
              backgroundColor: c.accent,
              onPressed: () => _createLesson(context, ws),
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text('수업 만들기', style: AppType.label1.copyWith(color: Colors.white)),
            ),
      body: SafeArea(child: _body(context, ws, lessons)),
    );
  }

  Widget _body(BuildContext context, TeacherWorkspace ws, List<Lesson> lessons) {
    if (_tab == 1) {
      return _worksheetLauncher(context, ws);
    }
    final filtered = switch (_tab) {
      3 => lessons.where((l) => l.slides.any((s) => s.type == LessonSlideType.ideaBoard)).toList(),
      4 => lessons.where((l) => l.slides.any((s) => s.type == LessonSlideType.quiz)).toList(),
      _ => lessons, // 전체 · 실시간수업
    };
    final c = context.c;
    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.cast_for_education_outlined, size: 48, color: c.labelAssistive),
            const SizedBox(height: AppSpace.s12),
            Text('아직 수업이 없어요.', style: AppType.body1.copyWith(color: c.labelAlt)),
            const SizedBox(height: 4),
            Text('‘수업 만들기’로 슬라이드 수업을 만들어요.', style: AppType.body2.copyWith(color: c.labelAssistive)),
          ]),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(AppSpace.s20),
      children: [
        for (final l in filtered)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.s8),
            child: Material(
              color: c.bgElevated,
              borderRadius: AppRadius.b14,
              child: InkWell(
                borderRadius: AppRadius.b14,
                onTap: () => context.push('/t/lessons/edit', extra: l),
                child: Container(
                  padding: const EdgeInsets.all(AppSpace.s16),
                  decoration: BoxDecoration(borderRadius: AppRadius.b14, border: Border.all(color: c.lineAlt)),
                  child: Row(children: [
                    Icon(Icons.slideshow_outlined, color: c.accent),
                    const SizedBox(width: AppSpace.s12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(l.title.isEmpty ? '제목 없는 수업' : l.title, style: AppType.body1.copyWith(color: c.labelNormal)),
                        Text('슬라이드 ${l.slides.length}개', style: AppType.caption1.copyWith(color: c.labelAlt)),
                      ]),
                    ),
                    IconButton(
                      tooltip: '수업 시작(실시간)',
                      icon: Icon(Icons.play_circle_outline, color: c.accent),
                      onPressed: l.slides.isEmpty ? null : () => context.push('/t/lessons/live', extra: l),
                    ),
                    Icon(Icons.chevron_right, color: c.labelAssistive),
                  ]),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _worksheetLauncher(BuildContext context, TeacherWorkspace ws) {
    final c = context.c;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.description_outlined, size: 48, color: c.labelAssistive),
          const SizedBox(height: AppSpace.s12),
          Text('학습지는 교실별로 관리해요.', style: AppType.body1.copyWith(color: c.labelAlt)),
          const SizedBox(height: AppSpace.s16),
          FilledButton.icon(
            onPressed: () => ws.isAll
                ? context.push('/t/classrooms')
                : context.push('/t/classrooms/${ws.classroomId}/worksheets', extra: ws.classroomName),
            style: FilledButton.styleFrom(backgroundColor: c.accent),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: Text(ws.isAll ? '교실 선택' : '학습지 열기'),
          ),
        ]),
      ),
    );
  }

  Future<void> _createLesson(BuildContext context, TeacherWorkspace ws) async {
    final ctrl = TextEditingController();
    final c = context.c;
    final title = await showDialog<String>(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: c.bgElevated,
        title: const Text('새 수업'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: '수업 제목 (예: 식물의 숨은 색을 찾아보자)'),
          onSubmitted: (v) => Navigator.pop(dctx, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dctx), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(dctx, ctrl.text.trim()), child: const Text('만들기')),
        ],
      ),
    );
    if (title == null || title.isEmpty) return;
    try {
      final lesson = await ref.read(lessonRepositoryProvider).createLesson(
            title: title,
            classroomId: ws.classroomId ?? '',
            classroomName: ws.classroomName ?? '',
          );
      if (context.mounted) context.push('/t/lessons/edit', extra: lesson);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('수업을 만들지 못했어요.')));
      }
    }
  }
}
