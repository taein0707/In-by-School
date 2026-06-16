import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/assignment/assignment.dart';

/// 숙제 화면 공용 포맷/위젯(선생님·학생 공유).

String dateLabel(DateTime d) => '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

/// 마감일 라벨 — D-day 포함. now 는 호출부에서 주입(테스트 용이).
String dueLabel(DateTime? due, DateTime now) {
  if (due == null) return '마감 없음';
  final d0 = DateTime(due.year, due.month, due.day);
  final n0 = DateTime(now.year, now.month, now.day);
  final diff = d0.difference(n0).inDays;
  final base = '마감 ${dateLabel(due)}';
  if (diff == 0) return '$base · 오늘';
  if (diff > 0) return '$base · D-$diff';
  return '$base · 지남';
}

/// 상태 칩(완료/진행/시작 전).
class StatusChip extends StatelessWidget {
  final SubmissionStatus status;
  const StatusChip(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (bg, fg) = switch (status) {
      SubmissionStatus.done => (c.accentSoft, c.accent),
      SubmissionStatus.inProgress => (c.fill, c.labelNeutral),
      SubmissionStatus.assigned => (c.fill, c.labelAlt),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: AppRadius.bFull),
      child: Text(status.label, style: AppType.caption1.copyWith(color: fg)),
    );
  }
}
