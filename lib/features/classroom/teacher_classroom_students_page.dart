import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/classroom_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/widgets/ui.dart';

/// 교사: 교실 학생 관리(P2-2) — 학생 목록 + 이메일 초대 + 제거.
class TeacherClassroomStudentsPage extends ConsumerWidget {
  final String classroomId;
  final String? classroomName;
  const TeacherClassroomStudentsPage({super.key, required this.classroomId, this.classroomName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final students = ref.watch(classroomStudentsProvider(classroomId)).valueOrNull ?? const [];

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => context.pop()),
        title: Text(classroomName?.isNotEmpty == true ? '${classroomName!} · 학생' : '학생 관리', style: AppType.headline1),
        actions: [
          IconButton(
            tooltip: '파일로 일괄 등록',
            icon: const Icon(Icons.upload_file_outlined),
            onPressed: () => context.push('/t/classrooms/$classroomId/students/bulk', extra: classroomName),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: c.accent,
        onPressed: () => _openInviteSheet(context, ref),
        icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
        label: Text('학생 추가', style: AppType.label1.copyWith(color: Colors.white)),
      ),
      body: SafeArea(
        child: students.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.s32),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.groups_outlined, size: 48, color: c.labelAssistive),
                    const SizedBox(height: AppSpace.s12),
                    Text('아직 학생이 없어요.', style: AppType.body1.copyWith(color: c.labelAlt)),
                    const SizedBox(height: 4),
                    Text('오른쪽 아래 버튼으로 이메일로 학생을 추가하세요.', style: AppType.body2.copyWith(color: c.labelAssistive)),
                  ]),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(AppSpace.s20),
                children: students
                    .map((s) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpace.s8),
                          child: OclCard(
                            child: Row(children: [
                              CircleAvatar(radius: 18, backgroundColor: c.accentSoft, child: Icon(Icons.person, size: 18, color: c.accent)),
                              const SizedBox(width: AppSpace.s12),
                              Expanded(child: Text(s.displayName.isEmpty ? '학생' : s.displayName, style: AppType.body1.copyWith(color: c.labelNormal))),
                              IconButton(
                                icon: Icon(Icons.close, size: 20, color: c.labelAssistive),
                                onPressed: () => _confirmRemove(context, ref, s.userUid, s.displayName),
                              ),
                            ]),
                          ),
                        ))
                    .toList(),
              ),
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref, String studentUid, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${name.isEmpty ? '학생' : name}을(를) 교실에서 제거할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('제거')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(classroomRepositoryProvider).removeStudentFromClassroom(classroomId: classroomId, studentUid: studentUid);
    }
  }

  void _openInviteSheet(BuildContext context, WidgetRef ref) {
    final emailCtrl = TextEditingController();
    ({String uid, String displayName})? found;
    String? error;
    var busy = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.c.bgElevated,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: AppRadius.r24)),
      builder: (sheetCtx) {
        final c = sheetCtx.c;
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            Future<void> search() async {
              setSheet(() {
                busy = true;
                error = null;
                found = null;
              });
              final r = await ref.read(classroomRepositoryProvider).findUserByEmail(emailCtrl.text);
              setSheet(() {
                busy = false;
                found = r;
                if (r == null) error = '가입된 사용자를 찾을 수 없어요.';
              });
            }

            Future<void> add() async {
              final r = found;
              if (r == null) return;
              setSheet(() => busy = true);
              await ref.read(classroomRepositoryProvider).addStudentToClassroom(
                    classroomId: classroomId,
                    classroomName: classroomName ?? '',
                    studentUid: r.uid,
                    studentName: r.displayName,
                  );
              if (ctx.mounted) Navigator.pop(ctx);
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                  AppSpace.s20, AppSpace.s20, AppSpace.s20, MediaQuery.of(ctx).viewInsets.bottom + AppSpace.s24),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('학생 추가', style: AppType.title3),
                const SizedBox(height: AppSpace.s16),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      style: AppType.body1.copyWith(color: c.labelNormal),
                      decoration: _dec(c, '학생 이메일'),
                      onSubmitted: (_) => search(),
                    ),
                  ),
                  const SizedBox(width: AppSpace.s8),
                  FilledButton(
                    onPressed: busy ? null : search,
                    style: FilledButton.styleFrom(backgroundColor: c.accent, shape: RoundedRectangleBorder(borderRadius: AppRadius.b14)),
                    child: const Text('검색'),
                  ),
                ]),
                if (error != null) ...[
                  const SizedBox(height: AppSpace.s12),
                  Text(error!, style: AppType.body2.copyWith(color: c.negative)),
                ],
                if (found != null) ...[
                  const SizedBox(height: AppSpace.s16),
                  OclCard(
                    child: Row(children: [
                      CircleAvatar(radius: 18, backgroundColor: c.accentSoft, child: Icon(Icons.person, size: 18, color: c.accent)),
                      const SizedBox(width: AppSpace.s12),
                      Expanded(child: Text(found!.displayName.isEmpty ? '학생' : found!.displayName, style: AppType.body1)),
                    ]),
                  ),
                  const SizedBox(height: AppSpace.s16),
                  OclButton(busy ? '추가 중…' : '학생 추가', onPressed: busy ? null : add),
                ],
              ]),
            );
          },
        );
      },
    );
  }

  InputDecoration _dec(AppColors c, String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: c.bg,
        enabledBorder: OutlineInputBorder(borderRadius: AppRadius.b14, borderSide: BorderSide(color: c.lineAlt)),
        focusedBorder: OutlineInputBorder(borderRadius: AppRadius.b14, borderSide: BorderSide(color: c.accent, width: 2)),
        contentPadding: const EdgeInsets.all(AppSpace.s16),
      );
}
