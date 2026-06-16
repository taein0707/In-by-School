import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// 참여 활동 허브(P4) — 빙고 / 가로세로 퍼즐 / 퀴즈 대회 / 랜덤 룰렛.
class ParticipationHubPage extends StatelessWidget {
  final String classroomId;
  final String? classroomName;
  final bool teacher;
  const ParticipationHubPage({super.key, required this.classroomId, this.classroomName, this.teacher = false});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final base = teacher ? '/t/classrooms/$classroomId/engage' : '/classrooms/$classroomId/engage';
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => context.pop()),
        title: Text('참여 활동', style: AppType.headline1),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpace.s20),
          children: [
            _tile(context, '빙고', '턴제 단어 빙고', Icons.grid_on_outlined, '$base/bingo'),
            const SizedBox(height: AppSpace.s8),
            _tile(context, '가로세로 퍼즐', '단어·뜻으로 만드는 퍼즐', Icons.extension_outlined, '$base/crossword'),
            const SizedBox(height: AppSpace.s8),
            _tile(context, '퀴즈 대회', '실시간 점수 경쟁', Icons.emoji_events_outlined, '$base/quiz'),
            const SizedBox(height: AppSpace.s8),
            _tile(context, '랜덤 룰렛', '학생·모둠·번호 추첨', Icons.casino_outlined, '$base/roulette'),
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
