import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/engagement_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/engagement/bingo_game.dart';
import '../../shared/widgets/ui.dart';

/// 빙고 목록(P4-1) — 교사: 생성/삭제, 학생: 참가.
class BingoListPage extends ConsumerWidget {
  final String classroomId;
  final String? classroomName;
  final bool teacher;
  const BingoListPage({super.key, required this.classroomId, this.classroomName, this.teacher = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final games = ref.watch(classroomBingosProvider(classroomId)).valueOrNull ?? const [];

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => context.pop()),
        title: Text('빙고', style: AppType.headline1),
      ),
      floatingActionButton: teacher
          ? FloatingActionButton.extended(
              backgroundColor: c.accent,
              onPressed: () => _openCreate(context, ref),
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text('빙고 만들기', style: AppType.label1.copyWith(color: Colors.white)),
            )
          : null,
      body: SafeArea(
        child: games.isEmpty
            ? _empty(context)
            : ListView(
                padding: const EdgeInsets.all(AppSpace.s20),
                children: [for (final g in games) _card(context, ref, g)],
              ),
      ),
    );
  }

  Widget _card(BuildContext context, WidgetRef ref, BingoGame g) {
    final c = context.c;
    final status = switch (g.status) {
      BingoStatus.waiting => '대기',
      BingoStatus.playing => '진행 중',
      BingoStatus.finished => '종료',
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s8),
      child: InkWell(
        borderRadius: AppRadius.b16,
        onTap: () => context.push('/engage/bingo/${g.id}?t=${teacher ? 1 : 0}', extra: classroomName),
        child: OclCard(
          child: Row(children: [
            Icon(Icons.grid_on_outlined, color: c.accent),
            const SizedBox(width: AppSpace.s12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(g.title.isEmpty ? '빙고' : g.title, style: AppType.headline2),
                Text('${g.size}×${g.size} · ${g.mode.label} · 참가 ${g.turnOrder.length}명 · $status',
                    style: AppType.body2.copyWith(color: c.labelAlt)),
              ]),
            ),
            if (teacher)
              IconButton(
                icon: Icon(Icons.delete_outline, color: c.labelAssistive),
                onPressed: () => ref.read(bingoRepositoryProvider).deleteBingo(g.id),
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
    var size = 3;
    var mode = BingoMode.individual;
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
                Text('빙고 만들기', style: AppType.title3),
                const SizedBox(height: AppSpace.s16),
                TextField(controller: titleCtrl, style: AppType.body1.copyWith(color: c.labelNormal), decoration: _dec(c, '제목 (예: 영단어 빙고)')),
                const SizedBox(height: AppSpace.s16),
                SectionLabel('크기'),
                Wrap(spacing: AppSpace.s8, children: [
                  for (final n in [3, 4, 5])
                    ChoiceChip(
                      label: Text('$n×$n', style: AppType.label1.copyWith(color: size == n ? Colors.white : c.labelNeutral)),
                      selected: size == n,
                      onSelected: (_) => setSheet(() => size = n),
                      selectedColor: c.accent,
                      backgroundColor: c.bg,
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.b14, side: BorderSide(color: size == n ? c.accent : c.lineAlt)),
                    ),
                  ActionChip(
                    label: Text([3, 4, 5].contains(size) ? '사용자 지정' : '$size×$size',
                        style: AppType.label1.copyWith(color: [3, 4, 5].contains(size) ? c.labelNeutral : Colors.white)),
                    onPressed: () async {
                      final v = await _askNumber(ctx, '빙고 크기 N', size);
                      if (v != null && v >= 2 && v <= 8) setSheet(() => size = v);
                    },
                    backgroundColor: [3, 4, 5].contains(size) ? c.bg : c.accent,
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.b14, side: BorderSide(color: c.lineAlt)),
                  ),
                ]),
                const SizedBox(height: AppSpace.s16),
                SectionLabel('모드'),
                Row(children: [
                  for (final m in BingoMode.values)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpace.s8),
                      child: ChoiceChip(
                        label: Text(m.label, style: AppType.label1.copyWith(color: mode == m ? Colors.white : c.labelNeutral)),
                        selected: mode == m,
                        onSelected: (_) => setSheet(() => mode = m),
                        selectedColor: c.accent,
                        backgroundColor: c.bg,
                        shape: RoundedRectangleBorder(borderRadius: AppRadius.b14, side: BorderSide(color: mode == m ? c.accent : c.lineAlt)),
                      ),
                    ),
                ]),
                const SizedBox(height: AppSpace.s16),
                SectionLabel('단어 (줄바꿈/쉼표로 구분, ${size * size}개 이상 권장)'),
                TextField(
                  controller: wordsCtrl,
                  maxLines: 5,
                  style: AppType.body1.copyWith(color: c.labelNormal),
                  decoration: _dec(c, 'apple\nbanana\nschool ...'),
                ),
                const SizedBox(height: AppSpace.s20),
                OclButton(busy ? '만드는 중…' : '만들기', onPressed: busy
                    ? null
                    : () async {
                        final words = _parseWords(wordsCtrl.text);
                        if (words.length < 2) return;
                        setSheet(() => busy = true);
                        final game = await ref.read(bingoRepositoryProvider).createBingo(
                              classroomId: classroomId,
                              title: titleCtrl.text.trim(),
                              size: size,
                              mode: mode,
                              words: words,
                            );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) context.push('/engage/bingo/${game.id}?t=1', extra: classroomName);
                      }),
              ]),
            ),
          ),
        );
      },
    );
  }

  List<String> _parseWords(String raw) => raw
      .split(RegExp(r'[\n,]'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  Future<int?> _askNumber(BuildContext context, String title, int initial) {
    final ctrl = TextEditingController(text: '$initial');
    return showDialog<int>(
      context: context,
      builder: (ctx) {
        final c = ctx.c;
        return AlertDialog(
          backgroundColor: c.bgElevated,
          title: Text(title, style: AppType.title3),
          content: TextField(controller: ctrl, autofocus: true, keyboardType: TextInputType.number, style: AppType.body1.copyWith(color: c.labelNormal)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
            TextButton(onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text.trim())), child: const Text('확인')),
          ],
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

  Widget _empty(BuildContext context) {
    final c = context.c;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.grid_on_outlined, size: 48, color: c.labelAssistive),
          const SizedBox(height: AppSpace.s12),
          Text(teacher ? '아직 만든 빙고가 없어요.' : '진행 중인 빙고가 없어요.', style: AppType.body1.copyWith(color: c.labelAlt)),
          if (teacher) ...[
            const SizedBox(height: 4),
            Text('오른쪽 아래 버튼으로 빙고를 만들어보세요.', style: AppType.body2.copyWith(color: c.labelAssistive)),
          ],
        ]),
      ),
    );
  }
}
