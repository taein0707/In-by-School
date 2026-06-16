import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/announcement_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/announcement/announcement.dart';
import '../../shared/widgets/ui.dart';

IconData _typeIcon(AnnouncementType t) => switch (t) {
      AnnouncementType.notice => Icons.campaign_outlined,
      AnnouncementType.assignment => Icons.assignment_outlined,
      AnnouncementType.exam => Icons.fact_check_outlined,
      AnnouncementType.event => Icons.event_outlined,
    };

String _dateLabel(DateTime? d) => d == null
    ? ''
    : '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

/// 교실 공지사항(P2-1). teacher=true 면 작성/수정/삭제, false 면 읽기 전용.
class ClassroomNoticePage extends ConsumerWidget {
  final String classroomId;
  final String? classroomName;
  final bool teacher;
  const ClassroomNoticePage({
    super.key,
    required this.classroomId,
    this.classroomName,
    this.teacher = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final list = ref.watch(classroomAnnouncementsProvider(classroomId)).valueOrNull ?? const [];

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => context.pop()),
        title: Text(classroomName?.isNotEmpty == true ? '${classroomName!} · 공지' : '공지사항', style: AppType.headline1),
        actions: teacher
            ? [
                IconButton(
                  tooltip: '학생 관리',
                  icon: const Icon(Icons.groups_outlined),
                  onPressed: () => context.push('/t/classrooms/$classroomId/students', extra: classroomName),
                ),
              ]
            : null,
      ),
      floatingActionButton: teacher
          ? FloatingActionButton.extended(
              backgroundColor: c.accent,
              onPressed: () => _openEditor(context, ref),
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text('공지 작성', style: AppType.label1.copyWith(color: Colors.white)),
            )
          : null,
      body: SafeArea(
        child: list.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.s32),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.campaign_outlined, size: 48, color: c.labelAssistive),
                    const SizedBox(height: AppSpace.s12),
                    Text('아직 공지가 없어요.', style: AppType.body1.copyWith(color: c.labelAlt)),
                  ]),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(AppSpace.s20),
                children: list
                    .map((a) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpace.s8),
                          child: _card(context, ref, a),
                        ))
                    .toList(),
              ),
      ),
    );
  }

  Widget _card(BuildContext context, WidgetRef ref, Announcement a) {
    final c = context.c;
    return OclCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _pill(context, a.type),
            const SizedBox(width: AppSpace.s8),
            Expanded(child: Text(a.title, style: AppType.headline2)),
            if (teacher)
              PopupMenuButton<String>(
                icon: Icon(Icons.more_horiz, color: c.labelAssistive),
                onSelected: (v) {
                  if (v == 'edit') _openEditor(context, ref, existing: a);
                  if (v == 'delete') _confirmDelete(context, ref, a);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('수정')),
                  PopupMenuItem(value: 'delete', child: Text('삭제')),
                ],
              ),
          ]),
          if (a.content.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(a.content, style: AppType.body1.copyWith(color: c.labelNeutral, height: 1.5)),
          ],
          const SizedBox(height: 6),
          Text(_dateLabel(a.createdAt), style: AppType.caption1.copyWith(color: c.labelAssistive)),
        ],
      ),
    );
  }

  Widget _pill(BuildContext context, AnnouncementType t) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: c.accentSoft, borderRadius: AppRadius.bFull),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(_typeIcon(t), size: 13, color: c.accent),
        const SizedBox(width: 4),
        Text(t.label, style: AppType.caption2.copyWith(color: c.accent, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Announcement a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('공지를 삭제할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('삭제')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(announcementRepositoryProvider).deleteAnnouncement(a.id);
    }
  }

  void _openEditor(BuildContext context, WidgetRef ref, {Announcement? existing}) {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final contentCtrl = TextEditingController(text: existing?.content ?? '');
    var type = existing?.type ?? AnnouncementType.notice;
    var busy = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.c.bgElevated,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: AppRadius.r24)),
      builder: (sheetCtx) {
        final c = sheetCtx.c;
        return StatefulBuilder(
          builder: (ctx, setSheet) => Padding(
            padding: EdgeInsets.fromLTRB(
                AppSpace.s20, AppSpace.s20, AppSpace.s20, MediaQuery.of(ctx).viewInsets.bottom + AppSpace.s24),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(existing == null ? '공지 작성' : '공지 수정', style: AppType.title3),
              const SizedBox(height: AppSpace.s16),
              Wrap(
                spacing: AppSpace.s8,
                children: AnnouncementType.values
                    .map((t) => ChoiceChip(
                          label: Text(t.label),
                          selected: type == t,
                          onSelected: (_) => setSheet(() => type = t),
                        ))
                    .toList(),
              ),
              const SizedBox(height: AppSpace.s12),
              TextField(controller: titleCtrl, style: AppType.body1.copyWith(color: c.labelNormal), decoration: _dec(c, '제목')),
              const SizedBox(height: AppSpace.s12),
              TextField(
                controller: contentCtrl,
                maxLines: 4,
                style: AppType.body1.copyWith(color: c.labelNormal),
                decoration: _dec(c, '내용'),
              ),
              const SizedBox(height: AppSpace.s20),
              OclButton(busy ? '저장 중…' : '저장', onPressed: busy
                  ? null
                  : () async {
                      final title = titleCtrl.text.trim();
                      if (title.isEmpty) return;
                      setSheet(() => busy = true);
                      final repo = ref.read(announcementRepositoryProvider);
                      if (existing == null) {
                        await repo.createAnnouncement(
                            classroomId: classroomId, title: title, content: contentCtrl.text.trim(), type: type);
                      } else {
                        await repo.updateAnnouncement(Announcement(
                          id: existing.id,
                          classroomId: classroomId,
                          teacherUid: existing.teacherUid,
                          title: title,
                          content: contentCtrl.text.trim(),
                          type: type,
                        ));
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                    }),
            ]),
          ),
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
