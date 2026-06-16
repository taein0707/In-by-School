import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/study_report_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/report/study_report.dart';
import '../../shared/widgets/ui.dart';

PreferredSizeWidget _bar(BuildContext context, String title, {bool back = false, List<Widget>? actions}) {
  final c = context.c;
  return AppBar(
    backgroundColor: c.bg,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    centerTitle: false,
    titleSpacing: back ? 0 : AppSpace.s20,
    leading: back ? IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => context.pop()) : null,
    title: Text(title, style: AppType.headline1),
    actions: actions,
  );
}

String _dateLabel(DateTime? d) => d == null
    ? ''
    : '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

/// 선생님: 학생들이 제출한 학습 기록 목록.
class TeacherReportsPage extends ConsumerWidget {
  const TeacherReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final async = ref.watch(teacherReportsProvider);

    return Scaffold(
      appBar: _bar(context, '학습 기록'),
      body: SafeArea(
        top: false,
        child: async.when(
          loading: () => Center(child: CircularProgressIndicator(color: c.accent)),
          error: (e, _) => Center(child: Text('불러오지 못했어요.', style: AppType.body2.copyWith(color: c.labelAlt))),
          data: (list) => list.isEmpty
              ? _empty(context)
              : ListView(
                  padding: const EdgeInsets.all(AppSpace.s20),
                  children: list.map((r) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpace.s8),
                        child: _row(context, r),
                      )).toList(),
                ),
        ),
      ),
    );
  }

  Widget _empty(BuildContext context) {
    final c = context.c;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_edu_outlined, size: 48, color: c.labelAssistive),
            const SizedBox(height: AppSpace.s12),
            Text('아직 제출된 학습 기록이 없어요.', style: AppType.body1.copyWith(color: c.labelAlt)),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, StudyReport r) {
    final c = context.c;
    return InkWell(
      borderRadius: AppRadius.b16,
      onTap: () => context.push('/t/reports/detail', extra: r),
      child: OclCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(r.studentName.isEmpty ? '학생' : r.studentName, style: AppType.headline2)),
                Text(_dateLabel(r.submittedAt), style: AppType.body2.copyWith(color: c.labelAlt)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                if (r.subject.isNotEmpty) ...[
                  Text(r.subject, style: AppType.body2.copyWith(color: c.labelAlt)),
                  const SizedBox(width: AppSpace.s8),
                ],
                Text('${r.studyMinutes}분', style: AppType.body2.copyWith(color: c.labelAlt)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 선생님: 학습 기록 상세 — 학생 작성 내용 전체.
class TeacherReportDetailPage extends StatelessWidget {
  final StudyReport report;
  const TeacherReportDetailPage({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      appBar: _bar(context, report.studentName.isEmpty ? '학습 기록' : '${report.studentName} · 학습 기록', back: true),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpace.s20),
          children: [
            Row(
              children: [
                if (report.subject.isNotEmpty) ...[
                  _pill(context, report.subject),
                  const SizedBox(width: AppSpace.s8),
                ],
                _pill(context, '${report.studyMinutes}분'),
                const Spacer(),
                Text(_dateLabel(report.submittedAt), style: AppType.body2.copyWith(color: c.labelAlt)),
              ],
            ),
            const SizedBox(height: AppSpace.s20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpace.s16),
              decoration: BoxDecoration(
                color: c.bgElevated,
                borderRadius: AppRadius.b16,
                border: Border.all(color: c.lineAlt),
              ),
              child: Text(
                report.content.isEmpty ? '(작성 내용이 없어요)' : report.content,
                style: AppType.body1.copyWith(color: c.labelNormal, height: 1.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(BuildContext context, String t) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: c.fill, borderRadius: AppRadius.bFull),
      child: Text(t, style: AppType.caption1.copyWith(color: c.labelNeutral, fontWeight: FontWeight.w600)),
    );
  }
}
