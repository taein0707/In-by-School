import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// 수업 활동 도구 허브(P3-2) — 자리배치 / 모둠 / 발표추첨 / 타이머.
class ClassroomToolsPage extends StatelessWidget {
  final String classroomId;
  final String? classroomName;
  const ClassroomToolsPage({super.key, required this.classroomId, this.classroomName});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final base = '/t/classrooms/$classroomId/tools';
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => context.pop()),
        title: Text('수업 도구', style: AppType.headline1),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpace.s20),
          children: [
            _tile(context, '랜덤 자리 배치', '학생을 격자에 무작위 배치', Icons.grid_view_outlined, '$base/seats'),
            const SizedBox(height: AppSpace.s8),
            _tile(context, '모둠 만들기', '인원수 기준 랜덤 모둠 편성', Icons.groups_2_outlined, '$base/groups'),
            const SizedBox(height: AppSpace.s8),
            _tile(context, '발표 학생 추첨', '랜덤 추첨 + 최근 기록', Icons.campaign_outlined, '$base/presenter'),
            const SizedBox(height: AppSpace.s8),
            _tile(context, '타이머', '카운트다운 · 스톱워치', Icons.timer_outlined, '$base/timer'),
          ],
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, String label, String sub, IconData icon, String path) {
    final c = context.c;
    return Material(
      color: c.bgElevated,
      borderRadius: AppRadius.b14,
      child: InkWell(
        borderRadius: AppRadius.b14,
        onTap: () => context.push(path, extra: classroomName),
        child: Container(
          padding: const EdgeInsets.all(AppSpace.s16),
          decoration: BoxDecoration(borderRadius: AppRadius.b14, border: Border.all(color: c.lineAlt)),
          child: Row(children: [
            Icon(icon, color: c.accent),
            const SizedBox(width: AppSpace.s12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: AppType.body1.copyWith(color: c.labelNeutral)),
                Text(sub, style: AppType.body2.copyWith(color: c.labelAlt)),
              ]),
            ),
            Icon(Icons.chevron_right, color: c.labelAssistive),
          ]),
        ),
      ),
    );
  }
}
