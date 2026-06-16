import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/classroom_providers.dart';
import '../../app/presence_providers.dart';
import '../../app/teacher_workspace.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/classroom/classroom.dart';
import '../../domain/presence/student_presence.dart';
import '../../shared/widgets/lnb_tabs.dart';

/// 교사 학생 허브(P9-2) — 전체 학생 + 참여 현황(Activity Monitor) 진입.
/// 현재 교실(워크스페이스) 기준으로 명단이 스코프된다. LNB 로 세부 보기를 나눈다.
class TeacherStudentsHubPage extends ConsumerStatefulWidget {
  const TeacherStudentsHubPage({super.key});

  @override
  ConsumerState<TeacherStudentsHubPage> createState() => _TeacherStudentsHubPageState();
}

class _TeacherStudentsHubPageState extends ConsumerState<TeacherStudentsHubPage> {
  static const _tabs = ['전체', '미제출', '참여현황', '최근접속', '집중도'];
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final ws = ref.watch(teacherWorkspaceProvider);
    final students = ws.isAll
        ? (ref.watch(teacherStudentsProvider).valueOrNull ?? const [])
        : (ref.watch(classroomStudentsProvider(ws.classroomId!)).valueOrNull ?? const []);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: AppSpace.s20,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text('학생', style: AppType.headline1),
          Text('${ws.title} · ${students.length}명', style: AppType.caption1.copyWith(color: c.accent)),
        ]),
        actions: [
          if (!ws.isAll)
            IconButton(
              tooltip: '학생 관리',
              icon: const Icon(Icons.person_add_alt_1),
              onPressed: () => context.push('/t/classrooms/${ws.classroomId}/students', extra: ws.classroomName),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: LnbTabs(labels: _tabs, selected: _tab, onSelected: (i) => setState(() => _tab = i)),
        ),
      ),
      body: SafeArea(child: _body(context, ws, students)),
    );
  }

  Widget _body(BuildContext context, TeacherWorkspace ws, List<ClassroomMember> students) {
    switch (_tab) {
      case 0:
        return _roster(context, students);
      case 1:
        return _hintThenRoster(context, students,
            '숙제별 미제출 학생은 숙제 상세에서 확인할 수 있어요.', () => context.go('/t/assignments'));
      case 2:
        return _participation(context, ws, students);
      default:
        return _monitorLauncher(context, ws);
    }
  }

  Widget _roster(BuildContext context, List<ClassroomMember> students) {
    final c = context.c;
    if (students.isEmpty) {
      return _empty(c, '학생이 없어요.', '교실을 선택하거나 학생을 추가해요.');
    }
    return ListView(
      padding: const EdgeInsets.all(AppSpace.s20),
      children: [for (final s in students) _studentTile(c, s.displayName)],
    );
  }

  Widget _hintThenRoster(BuildContext context, List<ClassroomMember> students, String hint, VoidCallback onTap) {
    final c = context.c;
    return ListView(
      padding: const EdgeInsets.all(AppSpace.s20),
      children: [
        Material(
          color: c.accentSoft,
          borderRadius: AppRadius.b14,
          child: InkWell(
            borderRadius: AppRadius.b14,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.s16),
              child: Row(children: [
                Icon(Icons.info_outline, size: 20, color: c.accent),
                const SizedBox(width: AppSpace.s8),
                Expanded(child: Text(hint, style: AppType.body2.copyWith(color: c.labelNeutral))),
                Icon(Icons.chevron_right, color: c.accent),
              ]),
            ),
          ),
        ),
        const SizedBox(height: AppSpace.s12),
        for (final s in students) _studentTile(c, s.displayName),
      ],
    );
  }

  Widget _participation(BuildContext context, TeacherWorkspace ws, List<ClassroomMember> students) {
    final c = context.c;
    if (ws.isAll) {
      return _empty(c, '교실을 선택해주세요.', '참여 현황은 교실 단위로 표시돼요.');
    }
    final presence = {
      for (final p in ref.watch(classroomPresenceProvider(ws.classroomId!)).valueOrNull ?? const []) p.studentUid: p
    };
    return ListView(
      padding: const EdgeInsets.all(AppSpace.s20),
      children: [
        for (final s in students)
          _presenceTile(c, s.displayName, presence[s.userUid]?.status ?? StudentPresence.offline),
      ],
    );
  }

  Widget _monitorLauncher(BuildContext context, TeacherWorkspace ws) {
    final c = context.c;
    final canMonitor = kIsWeb && !ws.isAll;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.monitor_heart_outlined, size: 48, color: c.labelAssistive),
          const SizedBox(height: AppSpace.s12),
          Text('실시간 집중도·접속은 참여 모니터에서 봐요.', style: AppType.body1.copyWith(color: c.labelAlt), textAlign: TextAlign.center),
          const SizedBox(height: AppSpace.s16),
          FilledButton.icon(
            onPressed: canMonitor
                ? () => context.push('/t/classrooms/${ws.classroomId}/monitor', extra: ws.classroomName)
                : null,
            style: FilledButton.styleFrom(backgroundColor: c.accent),
            icon: const Icon(Icons.open_in_full, size: 18),
            label: const Text('참여 모니터 열기'),
          ),
          if (!canMonitor) ...[
            const SizedBox(height: AppSpace.s8),
            Text(ws.isAll ? '교실을 먼저 선택해주세요.' : '참여 모니터는 웹에서 지원돼요.',
                style: AppType.caption1.copyWith(color: c.labelAssistive)),
          ],
        ]),
      ),
    );
  }

  Widget _studentTile(AppColors c, String name) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.s8),
        child: Container(
          padding: const EdgeInsets.all(AppSpace.s12),
          decoration: BoxDecoration(color: c.bgElevated, borderRadius: AppRadius.b14, border: Border.all(color: c.lineAlt)),
          child: Row(children: [
            CircleAvatar(radius: 16, backgroundColor: c.accentSoft, child: Icon(Icons.person, size: 16, color: c.accent)),
            const SizedBox(width: AppSpace.s12),
            Expanded(child: Text(name.isEmpty ? '학생' : name, style: AppType.body1.copyWith(color: c.labelNormal))),
          ]),
        ),
      );

  Widget _presenceTile(AppColors c, String name, StudentPresence status) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.s8),
        child: Container(
          padding: const EdgeInsets.all(AppSpace.s12),
          decoration: BoxDecoration(color: c.bgElevated, borderRadius: AppRadius.b14, border: Border.all(color: c.lineAlt)),
          child: Row(children: [
            Text(status.emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: AppSpace.s12),
            Expanded(child: Text(name.isEmpty ? '학생' : name, style: AppType.body1.copyWith(color: c.labelNormal))),
            Text(status.label, style: AppType.caption1.copyWith(color: c.labelAlt)),
          ]),
        ),
      );

  Widget _empty(AppColors c, String title, String sub) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.groups_outlined, size: 48, color: c.labelAssistive),
            const SizedBox(height: AppSpace.s12),
            Text(title, style: AppType.body1.copyWith(color: c.labelAlt)),
            const SizedBox(height: 4),
            Text(sub, style: AppType.body2.copyWith(color: c.labelAssistive)),
          ]),
        ),
      );
}
