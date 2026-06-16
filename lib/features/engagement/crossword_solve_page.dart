import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/account_providers.dart';
import '../../app/engagement_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/engagement/crossword.dart';
import '../../domain/engagement/crossword_set.dart';
import '../../shared/widgets/ui.dart';

/// 가로세로 퍼즐 풀이(P4-2) — 칸 입력 + 힌트 + 정답 확인 + 진행률 저장.
class CrosswordSolvePage extends ConsumerStatefulWidget {
  final String setId;
  const CrosswordSolvePage({super.key, required this.setId});

  @override
  ConsumerState<CrosswordSolvePage> createState() => _CrosswordSolvePageState();
}

class _CrosswordSolvePageState extends ConsumerState<CrosswordSolvePage> {
  final Map<String, TextEditingController> _ctrls = {};
  final Map<String, String> _entries = {};
  bool _loaded = false;
  bool _checked = false;

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _ctrl(String cell) =>
      _ctrls.putIfAbsent(cell, () => TextEditingController(text: _entries[cell] ?? ''));

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final set = ref.watch(crosswordSetProvider(widget.setId)).valueOrNull;
    final mine = ref.watch(myCrosswordSubmissionProvider(widget.setId)).valueOrNull;

    if (set != null && !_loaded && mine != null) {
      _entries.addAll(mine.entries);
      _loaded = true;
    }

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => context.pop()),
        title: Text(set?.title.isNotEmpty == true ? set!.title : '가로세로 퍼즐', style: AppType.headline1),
        actions: [
          if (set != null)
            TextButton(onPressed: () => _save(set), child: Text('저장', style: AppType.label1.copyWith(color: c.accent))),
        ],
      ),
      body: SafeArea(
        child: set == null
            ? const Center(child: CircularProgressIndicator())
            : (set.puzzle.placed.isEmpty
                ? _empty(c)
                : ListView(
                    padding: const EdgeInsets.all(AppSpace.s20),
                    children: _content(c, set),
                  )),
      ),
    );
  }

  List<Widget> _content(AppColors c, CrosswordSet set) {
    final puzzle = set.puzzle;
    final solution = puzzle.solutionCells();
    final grade = CrosswordGrading.grade(puzzle, _entries);
    // 칸별 번호(시작 칸).
    final numbers = <String, int>{};
    for (final p in puzzle.placed) {
      numbers.putIfAbsent(CrosswordPuzzle.key(p.row, p.col), () => p.number);
    }

    return [
      Row(children: [
        Expanded(
          child: ClipRRect(
            borderRadius: AppRadius.b14,
            child: LinearProgressIndicator(value: grade.progress, minHeight: 10, backgroundColor: c.fill, color: c.accent),
          ),
        ),
        const SizedBox(width: AppSpace.s12),
        Text('${grade.correct}/${grade.total}', style: AppType.label1.copyWith(color: c.labelNeutral)),
      ]),
      if (grade.solved) ...[
        const SizedBox(height: AppSpace.s12),
        _banner(c, '🎉 퍼즐을 모두 맞혔어요!', c.accentSoft, c.accent),
      ],
      const SizedBox(height: AppSpace.s16),
      _grid(c, puzzle, solution, numbers),
      const SizedBox(height: AppSpace.s16),
      Row(children: [
        Expanded(child: OclButton('힌트', ghost: true, onPressed: () => _hint(puzzle, solution))),
        const SizedBox(width: AppSpace.s8),
        Expanded(child: OclButton('정답 확인', onPressed: () => setState(() => _checked = true))),
      ]),
      const SizedBox(height: AppSpace.s24),
      _clues(c, '가로', puzzle.across),
      const SizedBox(height: AppSpace.s16),
      _clues(c, '세로', puzzle.down),
    ];
  }

  Widget _grid(AppColors c, CrosswordPuzzle puzzle, Map<String, String> solution, Map<String, int> numbers) {
    return LayoutBuilder(builder: (ctx, box) {
      final cell = (box.maxWidth / puzzle.cols).clamp(28.0, 56.0);
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var r = 0; r < puzzle.rows; r++)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var col = 0; col < puzzle.cols; col++) _cell(c, r, col, cell, solution, numbers),
                ],
              ),
          ],
        ),
      );
    });
  }

  Widget _cell(AppColors c, int r, int col, double size, Map<String, String> solution, Map<String, int> numbers) {
    final key = CrosswordPuzzle.key(r, col);
    final sol = solution[key];
    if (sol == null) {
      return Container(width: size, height: size, margin: const EdgeInsets.all(1), color: Colors.transparent);
    }
    final wrong = _checked && (_entries[key] ?? '').trim().isNotEmpty &&
        _entries[key]!.trim().toLowerCase() != sol.trim().toLowerCase();
    final number = numbers[key];
    return Container(
      width: size,
      height: size,
      margin: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: c.bgElevated,
        borderRadius: AppRadius.b8,
        border: Border.all(color: wrong ? c.negative : c.lineAlt, width: wrong ? 2 : 1),
      ),
      child: Stack(children: [
        if (number != null)
          Positioned(left: 2, top: 1, child: Text('$number', style: AppType.label2.copyWith(color: c.labelAssistive, fontSize: 9))),
        Center(
          child: SizedBox(
            width: size,
            height: size,
            child: TextField(
              controller: _ctrl(key),
              textAlign: TextAlign.center,
              maxLength: 1,
              style: AppType.headline2.copyWith(color: wrong ? c.negative : c.labelStrong),
              decoration: const InputDecoration(counterText: '', border: InputBorder.none, contentPadding: EdgeInsets.zero, isDense: true),
              onChanged: (v) => setState(() {
                _checked = false;
                if (v.trim().isEmpty) {
                  _entries.remove(key);
                } else {
                  _entries[key] = v.trim();
                }
              }),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _clues(AppColors c, String title, List<PlacedWord> words) => OclCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: AppType.headline2),
          const SizedBox(height: AppSpace.s8),
          if (words.isEmpty)
            Text('없음', style: AppType.body2.copyWith(color: c.labelAssistive))
          else
            for (final w in words)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('${w.number}. ${w.clue.isEmpty ? '(${w.length}글자)' : w.clue}', style: AppType.body2.copyWith(color: c.labelNeutral)),
              ),
        ]),
      );

  void _hint(CrosswordPuzzle puzzle, Map<String, String> solution) {
    // 비어 있거나 틀린 첫 칸을 정답으로 채운다.
    final keys = solution.keys.toList()
      ..sort((a, b) {
        final pa = a.split('_'), pb = b.split('_');
        final ra = int.parse(pa[0]), rb = int.parse(pb[0]);
        return ra != rb ? ra.compareTo(rb) : int.parse(pa[1]).compareTo(int.parse(pb[1]));
      });
    for (final key in keys) {
      final cur = (_entries[key] ?? '').trim().toLowerCase();
      if (cur != solution[key]!.trim().toLowerCase()) {
        setState(() {
          _entries[key] = solution[key]!;
          _ctrl(key).text = solution[key]!;
          _checked = false;
        });
        return;
      }
    }
  }

  Future<void> _save(CrosswordSet set) async {
    final grade = CrosswordGrading.grade(set.puzzle, _entries);
    final name = ref.read(currentProfileProvider).valueOrNull?.displayName ?? '학생';
    await ref.read(crosswordRepositoryProvider).saveProgress(
          set: set,
          studentName: name,
          entries: _entries,
          correct: grade.correct,
          total: grade.total,
          solved: grade.solved,
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('저장했어요 (${grade.correct}/${grade.total})')));
    }
  }

  Widget _banner(AppColors c, String text, Color bg, Color fg) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpace.s16),
        decoration: BoxDecoration(color: bg, borderRadius: AppRadius.b16, border: Border.all(color: fg.withValues(alpha: 0.4))),
        child: Text(text, style: AppType.body1.copyWith(color: fg)),
      );

  Widget _empty(AppColors c) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.extension_outlined, size: 48, color: c.labelAssistive),
            const SizedBox(height: AppSpace.s12),
            Text('연결되는 단어가 부족해 퍼즐을 만들지 못했어요.', style: AppType.body1.copyWith(color: c.labelAlt), textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text('겹치는 글자가 있는 단어로 다시 만들어 주세요.', style: AppType.body2.copyWith(color: c.labelAssistive), textAlign: TextAlign.center),
          ]),
        ),
      );
}
