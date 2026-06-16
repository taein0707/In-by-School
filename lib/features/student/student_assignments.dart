import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/account_providers.dart';
import '../../app/app_providers.dart';
import '../../app/assignment_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/assignment/assignment.dart';
import '../../domain/growth/growth.dart';
import '../../shared/widgets/ui.dart';
import '../assignments/assignment_format.dart';

PreferredSizeWidget _bar(BuildContext context, String title, {bool back = false}) {
  final c = context.c;
  return AppBar(
    backgroundColor: c.bg,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    centerTitle: false,
    titleSpacing: back ? 0 : AppSpace.s20,
    leading: back ? IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => context.pop()) : null,
    title: Text(title, style: AppType.headline1),
  );
}

/// 학생 · 숙제 목록 (소속 학생 탭).
class StudentAssignmentsPage extends ConsumerWidget {
  const StudentAssignmentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final async = ref.watch(studentAssignmentsProvider);
    final subs = ref.watch(mySubmissionsProvider).value ?? const <String, Submission>{};

    return Scaffold(
      appBar: _bar(context, '숙제'),
      body: SafeArea(
        top: false,
        child: async.when(
          loading: () => Center(child: CircularProgressIndicator(color: c.accent)),
          error: (e, _) => Center(child: Text('불러오지 못했어요.', style: AppType.body2.copyWith(color: c.labelAlt))),
          data: (list) => list.isEmpty ? _empty(context) : _grouped(context, list, subs),
        ),
      ),
    );
  }

  /// 진행 상태로 묶어 표시 — 마감 임박 → 진행중 → 완료.
  Widget _grouped(BuildContext context, List<Assignment> list, Map<String, Submission> subs) {
    final now = DateTime.now();
    final n0 = DateTime(now.year, now.month, now.day);
    final dueSoon = <Assignment>[]; // 미완료 + 마감 3일 이내(지난 것 포함)
    final ongoing = <Assignment>[]; // 미완료 + 여유 있음/마감 없음
    final done = <Assignment>[];

    for (final a in list) {
      final status = subs[a.id]?.status ?? SubmissionStatus.assigned;
      if (status == SubmissionStatus.done) {
        done.add(a);
      } else if (a.dueDate != null &&
          DateTime(a.dueDate!.year, a.dueDate!.month, a.dueDate!.day).difference(n0).inDays <= 3) {
        dueSoon.add(a);
      } else {
        ongoing.add(a);
      }
    }

    SubmissionStatus st(Assignment a) => subs[a.id]?.status ?? SubmissionStatus.assigned;

    return ListView(
      padding: const EdgeInsets.all(AppSpace.s20),
      children: [
        if (dueSoon.isNotEmpty) ...[
          const SectionLabel('마감 임박'),
          ...dueSoon.map((a) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.s8), child: _row(context, a, st(a)))),
          const SizedBox(height: AppSpace.s12),
        ],
        if (ongoing.isNotEmpty) ...[
          const SectionLabel('진행중'),
          ...ongoing.map((a) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.s8), child: _row(context, a, st(a)))),
          const SizedBox(height: AppSpace.s12),
        ],
        if (done.isNotEmpty) ...[
          const SectionLabel('완료'),
          ...done.map((a) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.s8), child: _row(context, a, st(a)))),
        ],
      ],
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
            Icon(Icons.assignment_turned_in_outlined, size: 48, color: c.labelAssistive),
            const SizedBox(height: AppSpace.s12),
            Text('받은 숙제가 없어요.', style: AppType.body1.copyWith(color: c.labelAlt)),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, Assignment a, SubmissionStatus status) {
    final c = context.c;
    return InkWell(
      borderRadius: AppRadius.b16,
      onTap: () => context.push('/assignments/detail', extra: a),
      child: OclCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(a.title, style: AppType.headline2)),
                StatusChip(status),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                if (a.teacherName.isNotEmpty) ...[
                  Text('${a.teacherName} 선생님', style: AppType.body2.copyWith(color: c.labelAlt)),
                  const SizedBox(width: AppSpace.s8),
                ],
                Text(dueLabel(a.dueDate, DateTime.now()), style: AppType.body2.copyWith(color: c.labelAlt)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 학생 · 숙제 상세 — 완료 체크 + 메모 제출.
class StudentAssignmentDetailPage extends ConsumerStatefulWidget {
  final Assignment assignment;
  const StudentAssignmentDetailPage({super.key, required this.assignment});
  @override
  ConsumerState<StudentAssignmentDetailPage> createState() => _DetailState();
}

class _DetailState extends ConsumerState<StudentAssignmentDetailPage> {
  final _memo = TextEditingController();
  bool _memoLoaded = false;
  bool _busy = false;

  @override
  void dispose() {
    _memo.dispose();
    super.dispose();
  }

  Future<void> _toggleDone(bool done) async {
    // 보상 중복 방지 — '완료'로 전환되는 순간에만 1회 지급(이미 done 이면 제외).
    final wasDone = ref.read(mySubmissionsProvider).value?[widget.assignment.id]?.isDone ?? false;
    setState(() => _busy = true);
    try {
      await ref.read(assignmentRepositoryProvider).upsertMySubmission(
            assignment: widget.assignment,
            studentName: ref.read(currentProfileProvider).value?.displayName ?? '',
            status: done ? SubmissionStatus.done : SubmissionStatus.inProgress,
          );
      if (done && !wasDone) {
        ref.read(appProvider.notifier).awardXp(XpSource.assignmentDone, XpSource.assignmentDone.defaultXp);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveMemo() async {
    setState(() => _busy = true);
    try {
      await ref.read(assignmentRepositoryProvider).upsertMySubmission(
            assignment: widget.assignment,
            studentName: ref.read(currentProfileProvider).value?.displayName ?? '',
            memo: _memo.text.trim(),
          );
      if (mounted) {
        FocusScope.of(context).unfocus();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('메모를 제출했어요.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final a = widget.assignment;
    final sub = ref.watch(mySubmissionsProvider).value?[a.id];
    final done = sub?.isDone ?? false;
    // 기존 메모를 1회 프리필(사용자가 편집 시작하면 덮어쓰지 않음).
    if (!_memoLoaded && sub != null) {
      _memo.text = sub.memo;
      _memoLoaded = true;
    }

    return Scaffold(
      appBar: _bar(context, a.title, back: true),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpace.s20),
          children: [
            if (a.teacherName.isNotEmpty)
              Text('${a.teacherName} 선생님', style: AppType.body2.copyWith(color: c.labelAlt)),
            const SizedBox(height: 6),
            Text(dueLabel(a.dueDate, DateTime.now()), style: AppType.body2.copyWith(color: c.labelAlt)),
            if (a.description.isNotEmpty) ...[
              const SizedBox(height: AppSpace.s16),
              Text(a.description, style: AppType.body1.copyWith(color: c.labelNeutral)),
            ],
            const SizedBox(height: AppSpace.s24),
            // 완료 체크
            InkWell(
              borderRadius: AppRadius.b16,
              onTap: _busy ? null : () => _toggleDone(!done),
              child: Container(
                padding: const EdgeInsets.all(AppSpace.s16),
                decoration: BoxDecoration(
                  color: done ? c.accentSoft : c.bgElevated,
                  borderRadius: AppRadius.b16,
                  border: Border.all(color: done ? c.accent : c.lineAlt),
                ),
                child: Row(
                  children: [
                    Icon(done ? Icons.check_circle : Icons.radio_button_unchecked,
                        size: 26, color: done ? c.accent : c.labelAssistive),
                    const SizedBox(width: AppSpace.s12),
                    Text(done ? '완료했어요' : '완료하면 눌러주세요',
                        style: AppType.headline2.copyWith(color: done ? c.accent : c.labelNormal)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpace.s24),
            const SectionLabel('메모'),
            TextField(
              controller: _memo,
              maxLines: 4,
              style: AppType.body1.copyWith(color: c.labelNormal),
              decoration: InputDecoration(
                hintText: '선생님께 남길 메모 (예: 3번 문제가 어려웠어요)',
                filled: true,
                fillColor: c.bgElevated,
                enabledBorder:
                    OutlineInputBorder(borderRadius: AppRadius.b14, borderSide: BorderSide(color: c.lineAlt)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: AppRadius.b14, borderSide: BorderSide(color: c.accent, width: 2)),
                contentPadding: const EdgeInsets.all(AppSpace.s16),
              ),
            ),
            const SizedBox(height: AppSpace.s12),
            OclButton('메모 제출', ghost: true, onPressed: _busy ? null : _saveMemo),
          ],
        ),
      ),
    );
  }
}
