import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/assignment_providers.dart';
import '../../app/teacher_workspace.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/widgets/lnb_tabs.dart';

/// 교사 숙제 허브(P9-2 #5) — 숙제 관련 기능을 한곳에 통합.
/// '새 숙제'에서 유형(일반/플래시카드/AI/퍼즐/퀴즈대회)을 고르면 기존 생성 흐름으로 이어진다.
/// 기능을 삭제하지 않고 LNB 로 카테고리만 나눈다.
class TeacherHomeworkHubPage extends ConsumerStatefulWidget {
  const TeacherHomeworkHubPage({super.key});

  @override
  ConsumerState<TeacherHomeworkHubPage> createState() => _TeacherHomeworkHubPageState();
}

class _TeacherHomeworkHubPageState extends ConsumerState<TeacherHomeworkHubPage> {
  static const _tabs = ['전체', '일반', '플래시카드', 'AI문제', '퍼즐', '퀴즈대회'];
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final ws = ref.watch(teacherWorkspaceProvider);
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: AppSpace.s20,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text('숙제', style: AppType.headline1),
          Text(ws.title, style: AppType.caption1.copyWith(color: c.accent)),
        ]),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: LnbTabs(labels: _tabs, selected: _tab, onSelected: (i) => setState(() => _tab = i)),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: c.accent,
        onPressed: () => _newHomeworkSheet(context, ws),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('새 숙제', style: AppType.label1.copyWith(color: Colors.white)),
      ),
      body: SafeArea(child: _body(context, ws)),
    );
  }

  Widget _body(BuildContext context, TeacherWorkspace ws) {
    switch (_tab) {
      case 0:
      case 1:
        return _assignmentsList(context);
      case 2:
        return _launcher(context, '플래시카드 덱', '단어/개념 카드를 만들고 배포해요.', Icons.style_outlined, () => context.push('/t/flashcards'));
      case 3:
        return _launcher(context, 'AI 문제', '주제·카드로 자동 문제를 생성해요.', Icons.smart_toy_outlined, () => context.push('/t/ai'));
      case 4:
        return _launcher(context, '가로세로 퍼즐', '교실에서 단어 퍼즐을 풀어요.', Icons.grid_on_outlined, () => _goEngage(context, ws, 'crossword'));
      default:
        return _launcher(context, '퀴즈 대회', '실시간 퀴즈로 겨뤄요.', Icons.quiz_outlined, () => _goEngage(context, ws, 'quiz'));
    }
  }

  Widget _assignmentsList(BuildContext context) {
    final c = context.c;
    final list = ref.watch(teacherAssignmentsProvider).valueOrNull ?? const [];
    if (list.isEmpty) {
      return _empty(c, '아직 낸 숙제가 없어요.', '오른쪽 아래 ‘새 숙제’로 시작해요.');
    }
    return ListView(
      padding: const EdgeInsets.all(AppSpace.s20),
      children: [
        for (final a in list)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.s8),
            child: Material(
              color: c.bgElevated,
              borderRadius: AppRadius.b14,
              child: InkWell(
                borderRadius: AppRadius.b14,
                onTap: () => context.push('/t/assignments/detail', extra: a),
                child: Container(
                  padding: const EdgeInsets.all(AppSpace.s16),
                  decoration: BoxDecoration(borderRadius: AppRadius.b14, border: Border.all(color: c.lineAlt)),
                  child: Row(children: [
                    Icon(Icons.assignment_outlined, color: c.accent),
                    const SizedBox(width: AppSpace.s12),
                    Expanded(child: Text(a.title.isEmpty ? '숙제' : a.title, style: AppType.body1.copyWith(color: c.labelNormal))),
                    Icon(Icons.chevron_right, color: c.labelAssistive),
                  ]),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _launcher(BuildContext context, String title, String desc, IconData icon, VoidCallback onTap) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.all(AppSpace.s20),
      child: Material(
        color: c.bgElevated,
        borderRadius: AppRadius.b16,
        child: InkWell(
          borderRadius: AppRadius.b16,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(AppSpace.s20),
            decoration: BoxDecoration(borderRadius: AppRadius.b16, border: Border.all(color: c.lineAlt)),
            child: Row(children: [
              Container(
                width: 44, height: 44, alignment: Alignment.center,
                decoration: BoxDecoration(color: c.accentSoft, borderRadius: AppRadius.b12),
                child: Icon(icon, color: c.accent),
              ),
              const SizedBox(width: AppSpace.s12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: AppType.headline2.copyWith(color: c.labelNormal)),
                  Text(desc, style: AppType.body2.copyWith(color: c.labelAlt)),
                ]),
              ),
              Icon(Icons.chevron_right, color: c.labelAssistive),
            ]),
          ),
        ),
      ),
    );
  }

  void _goEngage(BuildContext context, TeacherWorkspace ws, String kind) {
    if (ws.isAll) {
      context.push('/t/classrooms'); // 교실 선택부터
    } else {
      context.push('/t/classrooms/${ws.classroomId}/engage/$kind', extra: ws.classroomName);
    }
  }

  void _newHomeworkSheet(BuildContext context, TeacherWorkspace ws) {
    final c = context.c;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.bgElevated,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: AppRadius.r24)),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('새 숙제 유형 선택', style: AppType.title3),
            const SizedBox(height: AppSpace.s16),
            _type(sheetCtx, '일반 숙제', Icons.assignment_outlined, () => context.push('/t/assignments/new')),
            _type(sheetCtx, '플래시카드', Icons.style_outlined, () => context.push('/t/flashcards/new')),
            _type(sheetCtx, 'AI 문제', Icons.smart_toy_outlined, () => context.push('/t/ai/new')),
            _type(sheetCtx, '가로세로 퍼즐', Icons.grid_on_outlined, () => _goEngage(context, ws, 'crossword')),
            _type(sheetCtx, '퀴즈 대회', Icons.quiz_outlined, () => _goEngage(context, ws, 'quiz')),
          ]),
        ),
      ),
    );
  }

  Widget _type(BuildContext sheetCtx, String label, IconData icon, VoidCallback go) {
    final c = sheetCtx.c;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s8),
      child: Material(
        color: c.bg,
        borderRadius: AppRadius.b14,
        child: InkWell(
          borderRadius: AppRadius.b14,
          onTap: () {
            Navigator.pop(sheetCtx);
            go();
          },
          child: Container(
            padding: const EdgeInsets.all(AppSpace.s16),
            decoration: BoxDecoration(borderRadius: AppRadius.b14, border: Border.all(color: c.lineAlt)),
            child: Row(children: [
              Icon(icon, color: c.accent),
              const SizedBox(width: AppSpace.s12),
              Expanded(child: Text(label, style: AppType.body1.copyWith(color: c.labelNormal))),
              Icon(Icons.chevron_right, color: c.labelAssistive),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _empty(AppColors c, String title, String sub) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.assignment_outlined, size: 48, color: c.labelAssistive),
            const SizedBox(height: AppSpace.s12),
            Text(title, style: AppType.body1.copyWith(color: c.labelAlt)),
            const SizedBox(height: 4),
            Text(sub, style: AppType.body2.copyWith(color: c.labelAssistive)),
          ]),
        ),
      );
}
