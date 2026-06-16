import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/classroom_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/classroom/classroom.dart';
import '../../shared/widgets/ui.dart';

/// 공통 앱바(선생님 화면용).
PreferredSizeWidget _bar(BuildContext context, String title, {List<Widget>? actions}) {
  final c = context.c;
  return AppBar(
    backgroundColor: c.bg,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    centerTitle: false,
    titleSpacing: AppSpace.s20,
    title: Text(title, style: AppType.headline1),
    actions: actions,
  );
}

/// 학생 탭 — 내 교실들에 속한 학생 모음(조회 전용).
/// 학생 추가/제거는 교실(교실 상세 → 학생 관리)에서 이메일로 진행한다.
/// (요청·승인·초대코드 시스템은 제거됨 — 교실 가입이 곧 연결.)
class TeacherStudentsPage extends ConsumerWidget {
  const TeacherStudentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final students = ref.watch(teacherStudentsProvider).valueOrNull ?? const <ClassroomMember>[];

    return Scaffold(
      appBar: _bar(context, '학생'),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(AppSpace.s20),
          children: [
            OclCard(
              child: Row(children: [
                Icon(Icons.meeting_room_outlined, color: c.accent),
                const SizedBox(width: AppSpace.s12),
                Expanded(
                  child: Text('학생은 교실에서 이메일로 추가해요.',
                      style: AppType.body2.copyWith(color: c.labelNeutral)),
                ),
                TextButton(
                  onPressed: () => context.push('/t/classrooms'),
                  child: Text('교실 관리', style: AppType.label1.copyWith(color: c.accent)),
                ),
              ]),
            ),
            const SizedBox(height: AppSpace.s16),
            SectionLabel('내 학생 (${students.length})'),
            if (students.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpace.s24),
                child: Text('아직 교실에 추가된 학생이 없어요.',
                    style: AppType.body2.copyWith(color: c.labelAlt)),
              )
            else
              ...students.map((m) => _studentRow(context, m.displayName)),
          ],
        ),
      ),
    );
  }

  Widget _studentRow(BuildContext context, String name) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s8),
      child: OclCard(
        child: Row(children: [
          CircleAvatar(radius: 16, backgroundColor: c.accentSoft, child: Icon(Icons.person, size: 18, color: c.accent)),
          const SizedBox(width: AppSpace.s12),
          Expanded(child: Text(name.isEmpty ? '이름 미설정' : name, style: AppType.body1)),
        ]),
      ),
    );
  }
}

/// 숙제·플래시카드·AI문제·통계 — 다음 단계에서 구현. 구조만 자리 잡아 둔다.
class TeacherStubPage extends StatelessWidget {
  final String title;
  final IconData icon;
  final String note;
  const TeacherStubPage({super.key, required this.title, required this.icon, required this.note});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      appBar: _bar(context, title),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: c.labelAssistive),
              const SizedBox(height: AppSpace.s12),
              Text(note, textAlign: TextAlign.center, style: AppType.body1.copyWith(color: c.labelAlt)),
            ],
          ),
        ),
      ),
    );
  }
}
