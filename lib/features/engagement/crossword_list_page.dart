import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/engagement_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/engagement/crossword.dart';
import '../../domain/engagement/crossword_set.dart';
import '../../shared/widgets/ui.dart';

/// 가로세로 퍼즐 목록(P4-2) — 교사: 생성/삭제/결과, 학생: 풀이.
class CrosswordListPage extends ConsumerWidget {
  final String classroomId;
  final String? classroomName;
  final bool teacher;
  const CrosswordListPage({super.key, required this.classroomId, this.classroomName, this.teacher = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final sets = ref.watch(classroomCrosswordsProvider(classroomId)).valueOrNull ?? const [];

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => context.pop()),
        title: Text('가로세로 퍼즐', style: AppType.headline1),
      ),
      floatingActionButton: teacher
          ? FloatingActionButton.extended(
              backgroundColor: c.accent,
              onPressed: () => _openCreate(context, ref),
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text('퍼즐 만들기', style: AppType.label1.copyWith(color: Colors.white)),
            )
          : null,
      body: SafeArea(
        child: sets.isEmpty
            ? _empty(context)
            : ListView(
                padding: const EdgeInsets.all(AppSpace.s20),
                children: [for (final s in sets) _card(context, ref, s)],
              ),
      ),
    );
  }

  Widget _card(BuildContext context, WidgetRef ref, CrosswordSet s) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s8),
      child: InkWell(
        borderRadius: AppRadius.b16,
        onTap: () => context.push('/engage/crossword/solve/${s.id}', extra: classroomName),
        child: OclCard(
          child: Row(children: [
            Icon(Icons.extension_outlined, color: c.accent),
            const SizedBox(width: AppSpace.s12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.title.isEmpty ? '퍼즐' : s.title, style: AppType.headline2),
                Text('단어 ${s.placedCount}개 · ${s.puzzle.rows}×${s.puzzle.cols}', style: AppType.body2.copyWith(color: c.labelAlt)),
              ]),
            ),
            if (teacher)
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: c.labelAssistive),
                onSelected: (v) {
                  if (v == 'results') context.push('/engage/crossword/results/${s.id}', extra: classroomName);
                  if (v == 'delete') ref.read(crosswordRepositoryProvider).deleteSet(s.id);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'results', child: Text('결과 보기')),
                  PopupMenuItem(value: 'delete', child: Text('삭제')),
                ],
              )
            else
              Icon(Icons.chevron_right, color: c.labelAssistive),
          ]),
        ),
      ),
    );
  }

  void _openCreate(BuildContext context, WidgetRef ref) {
    final titleCtrl = TextEditingController();
    final wordsCtrl = TextEditingController();
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
            padding: EdgeInsets.fromLTRB(AppSpace.s20, AppSpace.s20, AppSpace.s20, MediaQuery.of(ctx).viewInsets.bottom + AppSpace.s24),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('퍼즐 만들기', style: AppType.title3),
                const SizedBox(height: AppSpace.s16),
                TextField(controller: titleCtrl, style: AppType.body1.copyWith(color: c.labelNormal), decoration: _dec(c, '제목 (예: 과일 단어)')),
                const SizedBox(height: AppSpace.s16),
                SectionLabel('단어, 뜻 (한 줄에 하나씩)'),
                TextField(
                  controller: wordsCtrl,
                  maxLines: 7,
                  style: AppType.body1.copyWith(color: c.labelNormal),
                  decoration: _dec(c, 'apple, 사과\nbanana, 바나나\nschool, 학교'),
                ),
                const SizedBox(height: AppSpace.s8),
                Text('두 글자 이상, 서로 겹치는 글자가 있어야 잘 연결돼요.', style: AppType.body2.copyWith(color: c.labelAssistive)),
                const SizedBox(height: AppSpace.s20),
                OclButton(busy ? '만드는 중…' : '만들기', onPressed: busy
                    ? null
                    : () async {
                        final words = _parse(wordsCtrl.text);
                        if (words.length < 2) return;
                        setSheet(() => busy = true);
                        final set = await ref.read(crosswordRepositoryProvider).createSet(
                              classroomId: classroomId,
                              title: titleCtrl.text.trim(),
                              words: words,
                            );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) context.push('/engage/crossword/solve/${set.id}', extra: classroomName);
                      }),
              ]),
            ),
          ),
        );
      },
    );
  }

  List<CrosswordWord> _parse(String raw) {
    final out = <CrosswordWord>[];
    for (final line in raw.split('\n')) {
      final t = line.trim();
      if (t.isEmpty) continue;
      final idx = t.indexOf(RegExp(r'[,\t]'));
      if (idx < 0) {
        out.add(CrosswordWord(word: t, clue: ''));
      } else {
        out.add(CrosswordWord(word: t.substring(0, idx).trim(), clue: t.substring(idx + 1).trim()));
      }
    }
    return out;
  }

  InputDecoration _dec(AppColors c, String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: c.bg,
        enabledBorder: OutlineInputBorder(borderRadius: AppRadius.b14, borderSide: BorderSide(color: c.lineAlt)),
        focusedBorder: OutlineInputBorder(borderRadius: AppRadius.b14, borderSide: BorderSide(color: c.accent, width: 2)),
        contentPadding: const EdgeInsets.all(AppSpace.s16),
      );

  Widget _empty(BuildContext context) {
    final c = context.c;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.extension_outlined, size: 48, color: c.labelAssistive),
          const SizedBox(height: AppSpace.s12),
          Text(teacher ? '아직 만든 퍼즐이 없어요.' : '풀 수 있는 퍼즐이 없어요.', style: AppType.body1.copyWith(color: c.labelAlt)),
        ]),
      ),
    );
  }
}
