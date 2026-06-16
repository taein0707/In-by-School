import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/account_providers.dart';
import '../../app/assignment_providers.dart';
import '../../app/classroom_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/assignment/assignment.dart';
import '../../domain/classroom/classroom.dart';
import '../../shared/widgets/ui.dart';
import '../assignments/assignment_format.dart';

PreferredSizeWidget _bar(BuildContext context, String title, {List<Widget>? actions, bool back = false}) {
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

/// 선생님 · 숙제 목록 (탭).
class TeacherAssignmentsPage extends ConsumerWidget {
  const TeacherAssignmentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final async = ref.watch(teacherAssignmentsProvider);
    return Scaffold(
      appBar: _bar(context, '숙제'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/t/assignments/new'),
        backgroundColor: c.accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('숙제 내기'),
      ),
      body: SafeArea(
        top: false,
        child: async.when(
          loading: () => Center(child: CircularProgressIndicator(color: c.accent)),
          error: (e, _) => Center(child: Text('불러오지 못했어요.', style: AppType.body2.copyWith(color: c.labelAlt))),
          data: (list) => list.isEmpty
              ? _empty(context)
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpace.s20),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpace.s8),
                  itemBuilder: (_, i) => _TeacherAssignmentRow(assignment: list[i]),
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
            Icon(Icons.assignment_outlined, size: 48, color: c.labelAssistive),
            const SizedBox(height: AppSpace.s12),
            Text('아직 낸 숙제가 없어요.\n오른쪽 아래 버튼으로 첫 숙제를 내보세요.',
                textAlign: TextAlign.center, style: AppType.body1.copyWith(color: c.labelAlt)),
          ],
        ),
      ),
    );
  }

}

/// 선생님 숙제 목록의 한 행 — 제목·마감일·대상 학생 수 + 제출 현황(완료 N/M명) 실시간.
class _TeacherAssignmentRow extends ConsumerWidget {
  final Assignment assignment;
  const _TeacherAssignmentRow({required this.assignment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final a = assignment;
    final subs = ref.watch(submissionsForAssignmentProvider(a.id)).value ?? const {};
    final total = a.studentUids.length;
    final doneCount = a.studentUids.where((u) => subs[u]?.isDone ?? false).length;
    final allDone = total > 0 && doneCount == total;

    return InkWell(
      borderRadius: AppRadius.b16,
      onTap: () => context.push('/t/assignments/detail', extra: a),
      child: OclCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(a.title, style: AppType.headline2)),
                Text('학생 $total명', style: AppType.label2.copyWith(color: c.labelAlt)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(dueLabel(a.dueDate, DateTime.now()),
                      style: AppType.body2.copyWith(color: c.labelAlt)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.s8, vertical: 3),
                  decoration: BoxDecoration(
                    color: allDone ? c.accentSoft : c.fill,
                    borderRadius: AppRadius.bFull,
                  ),
                  child: Text('완료 $doneCount/$total',
                      style: AppType.caption1.copyWith(color: allDone ? c.accent : c.labelNeutral)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 선생님 · 숙제 생성.
class TeacherAssignmentCreatePage extends ConsumerStatefulWidget {
  const TeacherAssignmentCreatePage({super.key});
  @override
  ConsumerState<TeacherAssignmentCreatePage> createState() => _CreateState();
}

class _CreateState extends ConsumerState<TeacherAssignmentCreatePage> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  DateTime? _due;
  final Set<String> _selected = {};
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _pickDue() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _due ?? now.add(const Duration(days: 1)),
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _due = picked);
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) return setState(() => _error = '제목을 입력해주세요.');
    if (_selected.isEmpty) return setState(() => _error = '대상 학생을 한 명 이상 선택해주세요.');
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final profile = ref.read(currentProfileProvider).value;
      await ref.read(assignmentRepositoryProvider).createAssignment(
            teacherName: profile?.displayName ?? '',
            title: _title.text.trim(),
            description: _desc.text.trim(),
            dueDate: _due,
            studentUids: _selected.toList(),
          );
      if (mounted) context.pop();
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final students = ref.watch(teacherStudentsProvider).value ?? const <ClassroomMember>[];

    return Scaffold(
      appBar: _bar(context, '숙제 내기', back: true),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpace.s24),
          children: [
            _field(c, _title, '제목 (예: 영단어 50개 암기)'),
            const SizedBox(height: AppSpace.s12),
            _field(c, _desc, '설명 (선택)', maxLines: 4),
            const SizedBox(height: AppSpace.s20),
            const SectionLabel('마감일'),
            InkWell(
              borderRadius: AppRadius.b14,
              onTap: _pickDue,
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16),
                decoration: BoxDecoration(
                  color: c.bgElevated,
                  borderRadius: AppRadius.b14,
                  border: Border.all(color: c.lineAlt),
                ),
                child: Row(
                  children: [
                    Icon(Icons.event_outlined, size: 20, color: c.labelAlt),
                    const SizedBox(width: AppSpace.s8),
                    Text(_due == null ? '마감일 선택 (선택)' : dateLabel(_due!),
                        style: AppType.body1.copyWith(color: _due == null ? c.labelAlt : c.labelNormal)),
                    const Spacer(),
                    if (_due != null)
                      InkWell(
                        onTap: () => setState(() => _due = null),
                        child: Icon(Icons.close, size: 18, color: c.labelAssistive),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpace.s20),
            SectionLabel('대상 학생 (${_selected.length}/${students.length})'),
            if (students.isEmpty)
              Text('교실에 추가된 학생이 없어요. ‘교실’에서 학생을 먼저 추가해주세요.',
                  style: AppType.body2.copyWith(color: c.labelAlt))
            else
              ...students.map((m) => _studentCheck(c, m)),
            if (_error != null) ...[
              const SizedBox(height: AppSpace.s12),
              Text(_error!, style: AppType.body2.copyWith(color: c.negative)),
            ],
            const SizedBox(height: AppSpace.s24),
            _saving
                ? Center(child: CircularProgressIndicator(color: c.accent))
                : OclButton('숙제 내기', onPressed: _save),
          ],
        ),
      ),
    );
  }

  Widget _studentCheck(AppColors c, ClassroomMember m) {
    final on = _selected.contains(m.userUid);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s8),
      child: InkWell(
        borderRadius: AppRadius.b14,
        onTap: () => setState(() => on ? _selected.remove(m.userUid) : _selected.add(m.userUid)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16, vertical: AppSpace.s12),
          decoration: BoxDecoration(
            color: on ? c.accentSoft : c.bgElevated,
            borderRadius: AppRadius.b14,
            border: Border.all(color: on ? c.accent : c.lineAlt),
          ),
          child: Row(
            children: [
              Icon(on ? Icons.check_circle : Icons.circle_outlined,
                  size: 22, color: on ? c.accent : c.labelAssistive),
              const SizedBox(width: AppSpace.s12),
              Text(m.displayName.isEmpty ? '이름 미설정' : m.displayName, style: AppType.body1),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(AppColors c, TextEditingController ctrl, String hint, {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: AppType.body1.copyWith(color: c.labelNormal),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: c.bgElevated,
        enabledBorder: OutlineInputBorder(borderRadius: AppRadius.b14, borderSide: BorderSide(color: c.lineAlt)),
        focusedBorder: OutlineInputBorder(borderRadius: AppRadius.b14, borderSide: BorderSide(color: c.accent, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.s16, vertical: AppSpace.s16),
      ),
    );
  }
}

/// 선생님 · 숙제 상세(학생별 완료 현황 실시간).
class TeacherAssignmentDetailPage extends ConsumerWidget {
  final Assignment assignment;
  const TeacherAssignmentDetailPage({super.key, required this.assignment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final subs = ref.watch(submissionsForAssignmentProvider(assignment.id)).value ?? const {};
    // 이름 조회: 연결된 학생 링크에서 uid→name.
    final names = {
      for (final m in (ref.watch(teacherStudentsProvider).value ?? const <ClassroomMember>[]))
        m.userUid: m.displayName,
    };
    final doneCount = assignment.studentUids.where((u) => subs[u]?.isDone ?? false).length;
    final total = assignment.studentUids.length;

    return Scaffold(
      appBar: _bar(context, assignment.title, back: true),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpace.s20),
          children: [
            if (assignment.description.isNotEmpty) ...[
              Text(assignment.description, style: AppType.body1.copyWith(color: c.labelNeutral)),
              const SizedBox(height: AppSpace.s12),
            ],
            Text(dueLabel(assignment.dueDate, DateTime.now()),
                style: AppType.body2.copyWith(color: c.labelAlt)),
            const SizedBox(height: AppSpace.s16),
            OclCard(
              child: Row(
                children: [
                  Text('완료', style: AppType.headline2),
                  const Spacer(),
                  Text('$doneCount / $total명',
                      style: AppType.headline1.copyWith(color: c.accent)),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.s20),
            const SectionLabel('학생별 현황'),
            ...assignment.studentUids.map((u) {
              final sub = subs[u];
              final name = (names[u] ?? sub?.studentName ?? '').trim();
              return _studentStatus(context, name.isEmpty ? '이름 미설정' : name, sub);
            }),
          ],
        ),
      ),
    );
  }

  Widget _studentStatus(BuildContext context, String name, Submission? sub) {
    final c = context.c;
    final status = sub?.status ?? SubmissionStatus.assigned;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s8),
      child: OclCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(name, style: AppType.body1)),
                StatusChip(status),
              ],
            ),
            if (sub != null && sub.memo.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('메모: ${sub.memo}', style: AppType.body2.copyWith(color: c.labelAlt)),
            ],
          ],
        ),
      ),
    );
  }
}
