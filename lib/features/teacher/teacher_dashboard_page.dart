import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/assignment_providers.dart';
import '../../app/classroom_providers.dart';
import '../../app/presence_providers.dart';
import '../../app/teacher_workspace.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/presence/student_presence.dart';

/// 교사 홈(P9-2 #4) — 교실 중심 대시보드. 현재 교실(워크스페이스) 기준으로 스코프된다.
class TeacherDashboardPage extends ConsumerWidget {
  const TeacherDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final ws = ref.watch(teacherWorkspaceProvider);
    final classrooms = ref.watch(teacherClassroomsProvider).valueOrNull ?? const [];
    final students = ws.isAll
        ? (ref.watch(teacherStudentsProvider).valueOrNull ?? const [])
        : (ref.watch(classroomStudentsProvider(ws.classroomId!)).valueOrNull ?? const []);
    final assignments = ref.watch(teacherAssignmentsProvider).valueOrNull ?? const [];

    return Scaffold(
      backgroundColor: c.bg,
      appBar: _bar(context, '홈', ws.title),
      body: ListView(
        padding: const EdgeInsets.all(AppSpace.s20),
        children: [
          // 통계 카드
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: AppSpace.s8,
            mainAxisSpacing: AppSpace.s8,
            childAspectRatio: 2.4,
            children: [
              _stat(c, '교실 수', '${classrooms.length}', Icons.meeting_room_outlined),
              _stat(c, '학생 수', '${students.length}', Icons.groups_outlined),
              _stat(c, '낸 숙제', '${assignments.length}', Icons.assignment_outlined),
              _stat(c, '오늘 수업', '준비', Icons.cast_for_education_outlined),
            ],
          ),
          const SizedBox(height: AppSpace.s24),
          Text('빠른 실행', style: AppType.heading2.copyWith(color: c.labelStrong)),
          const SizedBox(height: AppSpace.s12),
          Wrap(
            spacing: AppSpace.s8,
            runSpacing: AppSpace.s8,
            children: [
              _quick(context, '숙제 만들기', Icons.assignment_add, () => context.go('/t/assignments')),
              _quick(context, '수업 만들기', Icons.add_to_queue_outlined, () => context.go('/t/lessons')),
              _quick(context, '공지 작성', Icons.campaign_outlined, () => _goClassroom(context, ws, 'notices')),
              _quick(context, '학생 관리', Icons.manage_accounts_outlined, () => context.go('/t/students')),
              _quick(context, '수업 도구', Icons.dashboard_customize_outlined, () => _goClassroom(context, ws, 'tools')),
              _quick(context, '교실 설정', Icons.settings_outlined, () => context.push('/t/classrooms')),
            ],
          ),
          const SizedBox(height: AppSpace.s24),
          Text('참여 현황', style: AppType.heading2.copyWith(color: c.labelStrong)),
          const SizedBox(height: AppSpace.s12),
          _participation(context, ref, ws),
        ],
      ),
    );
  }

  void _goClassroom(BuildContext context, TeacherWorkspace ws, String sub) {
    if (ws.isAll) {
      context.push('/t/classrooms'); // 교실 선택부터
    } else {
      context.push('/t/classrooms/${ws.classroomId}/$sub', extra: ws.classroomName);
    }
  }

  Widget _participation(BuildContext context, WidgetRef ref, TeacherWorkspace ws) {
    final c = context.c;
    if (ws.isAll) {
      return _hintCard(c, '사이드바에서 교실을 선택하면 실시간 참여 현황이 표시돼요.');
    }
    final presence = ref.watch(classroomPresenceProvider(ws.classroomId!)).valueOrNull ?? const [];
    int count(StudentPresence s) => presence.where((p) => p.status == s).length;
    return Container(
      padding: const EdgeInsets.all(AppSpace.s16),
      decoration: BoxDecoration(color: c.bgElevated, borderRadius: AppRadius.b16, border: Border.all(color: c.lineAlt)),
      child: Wrap(
        spacing: AppSpace.s16,
        runSpacing: AppSpace.s12,
        children: [
          _pill(c, '🟢 참여중', count(StudentPresence.active), c.positive),
          _pill(c, '🟡 비활성', count(StudentPresence.idle), c.cautionary),
          _pill(c, '🔴 이탈', count(StudentPresence.away) + count(StudentPresence.offline), c.negative),
          _pill(c, '📺 화면공유', count(StudentPresence.screenSharing), c.accent),
        ],
      ),
    );
  }

  Widget _pill(AppColors c, String label, int n, Color color) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: AppType.body2.copyWith(color: c.labelNeutral)),
      const SizedBox(width: AppSpace.s8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.s8, vertical: 2),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: AppRadius.bFull),
        child: Text('$n', style: AppType.label1.copyWith(color: color, fontWeight: FontWeight.w700)),
      ),
    ]);
  }

  Widget _stat(AppColors c, String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.s16),
      decoration: BoxDecoration(color: c.bgElevated, borderRadius: AppRadius.b16, border: Border.all(color: c.lineAlt)),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: c.accentSoft, borderRadius: AppRadius.b12),
          child: Icon(icon, size: 20, color: c.accent),
        ),
        const SizedBox(width: AppSpace.s12),
        Expanded(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: AppType.title3.copyWith(color: c.labelStrong, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(label, style: AppType.caption1.copyWith(color: c.labelAlt)),
          ]),
        ),
      ]),
    );
  }

  Widget _quick(BuildContext context, String label, IconData icon, VoidCallback onTap) {
    final c = context.c;
    return SizedBox(
      width: 150,
      child: Material(
        color: c.bgElevated,
        borderRadius: AppRadius.b14,
        child: InkWell(
          borderRadius: AppRadius.b14,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.s12, vertical: AppSpace.s14),
            decoration: BoxDecoration(borderRadius: AppRadius.b14, border: Border.all(color: c.lineAlt)),
            child: Row(children: [
              Icon(icon, size: 20, color: c.accent),
              const SizedBox(width: AppSpace.s8),
              Expanded(child: Text(label, style: AppType.label1.copyWith(color: c.labelNeutral), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _hintCard(AppColors c, String text) => Container(
        padding: const EdgeInsets.all(AppSpace.s16),
        decoration: BoxDecoration(color: c.accentSoft, borderRadius: AppRadius.b16),
        child: Text(text, style: AppType.body2.copyWith(color: c.labelNeutral)),
      );

  PreferredSizeWidget _bar(BuildContext context, String title, String workspace) => AppBar(
        backgroundColor: context.c.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: AppSpace.s20,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(title, style: AppType.headline1),
          Text(workspace, style: AppType.caption1.copyWith(color: context.c.accent)),
        ]),
      );
}
