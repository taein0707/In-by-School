import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../brand/class_enter_intro.dart';

/// 교실 상세 허브(P3-1) — 공지 / 학생(교사) / 학습지 진입.
class ClassroomDetailPage extends StatefulWidget {
  final String classroomId;
  final String? classroomName;
  final bool teacher;
  const ClassroomDetailPage({super.key, required this.classroomId, this.classroomName, this.teacher = false});

  @override
  State<ClassroomDetailPage> createState() => _ClassroomDetailPageState();
}

class _ClassroomDetailPageState extends State<ClassroomDetailPage> {
  @override
  void initState() {
    super.initState();
    // 학생이 교실에 들어오면 "수업 입장" 브랜드 인트로를 한 번 재생.
    if (!widget.teacher) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ClassEnterIntro.show(context, widget.classroomName);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final classroomId = widget.classroomId;
    final classroomName = widget.classroomName;
    final teacher = widget.teacher;
    final base = teacher ? '/t/classrooms/$classroomId' : '/classrooms/$classroomId';
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => context.pop()),
        title: Text(classroomName?.isNotEmpty == true ? classroomName! : '교실', style: AppType.headline1),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpace.s20),
          children: [
            if (!teacher) ...[
              // 학생: 진행 중인 실시간 수업 참여(P10-2).
              _tile(context, '실시간 수업', Icons.cast_outlined, '/live/$classroomId'),
              const SizedBox(height: AppSpace.s8),
            ],
            _tile(context, '공지사항', Icons.campaign_outlined, '$base/notices'),
            const SizedBox(height: AppSpace.s8),
            if (teacher) ...[
              _tile(context, '학생 관리', Icons.groups_outlined, '$base/students'),
              const SizedBox(height: AppSpace.s8),
            ],
            _tile(context, '학습지', Icons.description_outlined, '$base/worksheets'),
            if (teacher) ...[
              const SizedBox(height: AppSpace.s8),
              _tile(context, '수업 도구', Icons.dashboard_customize_outlined, '$base/tools'),
              // 참여 모니터는 웹 전용(P6) — 웹에서만 노출.
              if (kIsWeb) ...[
                const SizedBox(height: AppSpace.s8),
                _tile(context, '참여 모니터', Icons.monitor_heart_outlined, '$base/monitor'),
              ],
            ],
            const SizedBox(height: AppSpace.s8),
            _tile(context, '참여 활동', Icons.celebration_outlined, '$base/engage'),
          ],
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, String label, IconData icon, String path) {
    final c = context.c;
    return Material(
      color: c.bgElevated,
      borderRadius: AppRadius.b14,
      child: InkWell(
        borderRadius: AppRadius.b14,
        onTap: () => context.push(path, extra: widget.classroomName),
        child: Container(
          padding: const EdgeInsets.all(AppSpace.s16),
          decoration: BoxDecoration(borderRadius: AppRadius.b14, border: Border.all(color: c.lineAlt)),
          child: Row(children: [
            Icon(icon, color: c.accent),
            const SizedBox(width: AppSpace.s12),
            Expanded(child: Text(label, style: AppType.body1.copyWith(color: c.labelNeutral))),
            Icon(Icons.chevron_right, color: c.labelAssistive),
          ]),
        ),
      ),
    );
  }
}
