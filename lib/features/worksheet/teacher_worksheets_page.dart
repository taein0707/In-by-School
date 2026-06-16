import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/worksheet_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/widgets/ui.dart';

/// 교사: 교실 학습지 목록 + 생성 + 편집 진입 + 삭제(P3-1).
class TeacherWorksheetsPage extends ConsumerWidget {
  final String classroomId;
  final String? classroomName;
  const TeacherWorksheetsPage({super.key, required this.classroomId, this.classroomName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final sheets = ref.watch(classroomWorksheetsProvider(classroomId)).valueOrNull ?? const [];

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => context.pop()),
        title: Text('학습지', style: AppType.headline1),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: c.accent,
        onPressed: () => _createSheet(context, ref),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('학습지 만들기', style: AppType.label1.copyWith(color: Colors.white)),
      ),
      body: SafeArea(
        child: sheets.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.s32),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.description_outlined, size: 48, color: c.labelAssistive),
                    const SizedBox(height: AppSpace.s12),
                    Text('아직 학습지가 없어요.', style: AppType.body1.copyWith(color: c.labelAlt)),
                  ]),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(AppSpace.s20),
                children: sheets
                    .map((w) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpace.s8),
                          child: InkWell(
                            borderRadius: AppRadius.b16,
                            onTap: () => context.push('/worksheets/edit', extra: w),
                            child: OclCard(
                              child: Row(children: [
                                Icon(Icons.description_outlined, color: c.accent),
                                const SizedBox(width: AppSpace.s12),
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(w.title, style: AppType.headline2),
                                    if (w.description.isNotEmpty)
                                      Text(w.description, style: AppType.body2.copyWith(color: c.labelAlt)),
                                  ]),
                                ),
                                PopupMenuButton<String>(
                                  icon: Icon(Icons.more_horiz, color: c.labelAssistive),
                                  onSelected: (v) {
                                    if (v == 'results') context.push('/worksheets/results', extra: w);
                                    if (v == 'delete') _confirmDelete(context, ref, w.id, w.title);
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(value: 'results', child: Text('결과 보기')),
                                    PopupMenuItem(value: 'delete', child: Text('삭제')),
                                  ],
                                ),
                              ]),
                            ),
                          ),
                        ))
                    .toList(),
              ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, String id, String title) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('"$title" 학습지를 삭제할까요?'),
        content: const Text('문항과 제출 결과가 함께 삭제돼요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('삭제')),
        ],
      ),
    );
    if (ok == true) await ref.read(worksheetRepositoryProvider).deleteWorksheet(id);
  }

  void _createSheet(BuildContext context, WidgetRef ref) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
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
              Text('학습지 만들기', style: AppType.title3),
              const SizedBox(height: AppSpace.s16),
              TextField(controller: titleCtrl, style: AppType.body1.copyWith(color: c.labelNormal), decoration: _dec(c, '학습지 제목')),
              const SizedBox(height: AppSpace.s12),
              TextField(controller: descCtrl, style: AppType.body1.copyWith(color: c.labelNormal), decoration: _dec(c, '설명 (선택)')),
              const SizedBox(height: AppSpace.s20),
              OclButton(busy ? '만드는 중…' : '만들기', onPressed: busy
                  ? null
                  : () async {
                      final title = titleCtrl.text.trim();
                      if (title.isEmpty) return;
                      setSheet(() => busy = true);
                      final w = await ref.read(worksheetRepositoryProvider).createWorksheet(
                          classroomId: classroomId, title: title, description: descCtrl.text.trim());
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        context.push('/worksheets/edit', extra: w); // 만들고 바로 편집
                      }
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
