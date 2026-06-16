import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/lesson_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/ai/gemini_service.dart';
import '../../domain/lesson/lesson.dart';

/// 슬라이드 수업 에디터(P10) — 30+종 슬라이드, 드래그앤드롭 정렬, 유형별 편집, AI 수정.
class TeacherLessonEditorPage extends ConsumerStatefulWidget {
  final Lesson lesson;
  const TeacherLessonEditorPage({super.key, required this.lesson});

  @override
  ConsumerState<TeacherLessonEditorPage> createState() => _TeacherLessonEditorPageState();
}

class _TeacherLessonEditorPageState extends ConsumerState<TeacherLessonEditorPage> {
  late final TextEditingController _title;
  late List<LessonSlide> _slides;
  bool _saving = false;
  bool _aiBusy = false;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.lesson.title);
    _slides = List.of(widget.lesson.slides);
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  String _newId() => 's${DateTime.now().microsecondsSinceEpoch}_${_seq++}';

  Future<void> _save() async {
    setState(() => _saving = true);
    final updated = widget.lesson.copyWith(title: _title.text.trim(), slides: _slides);
    try {
      await ref.read(lessonRepositoryProvider).saveLesson(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('저장했어요.')));
        context.pop();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('저장하지 못했어요.')));
      }
    }
  }

  Future<void> _aiEdit() async {
    final instruction = await _promptText('AI 수정', '예) 퀴즈를 3개 더 추가해줘 / 설명을 더 쉽게 바꿔줘');
    if (instruction == null || instruction.isEmpty) return;
    setState(() => _aiBusy = true);
    final result = await GeminiService.editLesson(slides: _slides, instruction: instruction);
    if (!mounted) return;
    setState(() => _aiBusy = false);
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('AI 수정은 연결이 필요해요(오프라인).')));
      return;
    }
    setState(() => _slides = result.map((s) => s.copyWith()).toList());
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('AI가 ${result.length}장으로 수정했어요.')));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => context.pop()),
        title: Text('수업 편집', style: AppType.headline2),
        actions: [
          IconButton(
            tooltip: 'AI 수정',
            onPressed: _aiBusy ? null : _aiEdit,
            icon: _aiBusy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_fix_high),
          ),
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? '저장 중…' : '저장', style: AppType.label1.copyWith(color: c.accent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: c.accent,
        onPressed: _addSlideSheet,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('슬라이드 추가', style: AppType.label1.copyWith(color: Colors.white)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.s20, AppSpace.s16, AppSpace.s20, AppSpace.s8),
              child: TextField(
                controller: _title,
                style: AppType.title3.copyWith(color: c.labelStrong),
                decoration: InputDecoration(
                  hintText: '수업 제목',
                  filled: true,
                  fillColor: c.bgElevated,
                  enabledBorder: OutlineInputBorder(borderRadius: AppRadius.b14, borderSide: BorderSide(color: c.lineAlt)),
                  focusedBorder: OutlineInputBorder(borderRadius: AppRadius.b14, borderSide: BorderSide(color: c.accent, width: 2)),
                  contentPadding: const EdgeInsets.all(AppSpace.s16),
                ),
              ),
            ),
            Expanded(
              child: _slides.isEmpty
                  ? Center(child: Text('‘슬라이드 추가’로 시작해요.', style: AppType.body2.copyWith(color: c.labelAlt)))
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(AppSpace.s20, 0, AppSpace.s20, 96),
                      itemCount: _slides.length,
                      onReorder: (oldIndex, newIndex) {
                        setState(() {
                          if (newIndex > oldIndex) newIndex--;
                          final s = _slides.removeAt(oldIndex);
                          _slides.insert(newIndex, s);
                        });
                      },
                      itemBuilder: (context, i) => _slideCard(c, i, key: ValueKey(_slides[i].id)),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _slideCard(AppColors c, int i, {required Key key}) {
    final s = _slides[i];
    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: AppSpace.s8),
      child: Container(
        decoration: BoxDecoration(color: c.bgElevated, borderRadius: AppRadius.b14, border: Border.all(color: c.lineAlt)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.s12, AppSpace.s10, AppSpace.s4, AppSpace.s4),
            child: Row(children: [
              Icon(_catIcon(s.type.category), size: 18, color: c.accent),
              const SizedBox(width: AppSpace.s8),
              Expanded(
                child: Text('${i + 1} · ${s.type.label}', style: AppType.label2.copyWith(color: c.labelNeutral, fontWeight: FontWeight.w700)),
              ),
              IconButton(visualDensity: VisualDensity.compact, icon: Icon(Icons.delete_outline, size: 18, color: c.negative), onPressed: () => setState(() => _slides.removeAt(i))),
              ReorderableDragStartListener(index: i, child: Icon(Icons.drag_handle, size: 20, color: c.labelAssistive)),
              const SizedBox(width: AppSpace.s8),
            ]),
          ),
          InkWell(
            onTap: () => _editSlide(i),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.s12, 0, AppSpace.s12, AppSpace.s14),
              child: Align(alignment: Alignment.centerLeft, child: Text(_summary(s), style: AppType.body2.copyWith(color: c.labelNeutral))),
            ),
          ),
        ]),
      ),
    );
  }

  String _summary(LessonSlide s) {
    if (s.type == LessonSlideType.timer) return '타이머 ${(s.timerSeconds / 60).round()}분';
    if (s.type.hasNumber && s.number > 0) return '${s.type.label} · ${s.number}${s.type.numberUnit}';
    if (s.type.hasMedia) return s.mediaUrl.isEmpty ? '${s.type.label} · URL을 입력하세요' : s.mediaUrl;
    if (s.text.isNotEmpty) return s.text;
    if (s.type.hasChoices && s.choices.isNotEmpty) return s.choices.join(' · ');
    return '${s.type.label} — 내용을 입력하세요';
  }

  IconData _catIcon(SlideCategory cat) => switch (cat) {
        SlideCategory.info => Icons.info_outline,
        SlideCategory.input => Icons.edit_note,
        SlideCategory.live => Icons.bolt_outlined,
        SlideCategory.flow => Icons.timelapse_outlined,
        SlideCategory.game => Icons.sports_esports_outlined,
        SlideCategory.wrap => Icons.flag_outlined,
      };

  void _addSlideSheet() {
    final c = context.c;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.bgElevated,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: AppRadius.r24)),
      builder: (sc) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.92,
        builder: (_, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.all(AppSpace.s20),
          children: [
            Text('슬라이드 추가', style: AppType.title3),
            const SizedBox(height: AppSpace.s12),
            for (final cat in SlideCategory.values) ...[
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.s8, bottom: AppSpace.s4),
                child: Text(cat.label, style: AppType.label2.copyWith(color: c.labelAlt)),
              ),
              Wrap(
                spacing: AppSpace.s8,
                runSpacing: AppSpace.s8,
                children: [
                  for (final t in LessonSlideType.values.where((e) => e.category == cat))
                    ActionChip(
                      avatar: Icon(_catIcon(cat), size: 16, color: c.accent),
                      label: Text(t.label, style: AppType.label2.copyWith(color: c.labelNeutral)),
                      onPressed: () {
                        Navigator.pop(sc);
                        setState(() => _slides.add(_defaultSlide(t)));
                        _editSlide(_slides.length - 1);
                      },
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  LessonSlide _defaultSlide(LessonSlideType t) {
    final base = LessonSlide(id: _newId(), type: t);
    return switch (t) {
      LessonSlideType.ox => base.copyWith(choices: const ['O', 'X'], answer: 'O'),
      LessonSlideType.countdown => base.copyWith(number: 3),
      LessonSlideType.randomGroup => base.copyWith(number: 3),
      LessonSlideType.bingo => base.copyWith(number: 5),
      _ => base,
    };
  }

  void _editSlide(int i) {
    final s = _slides[i];
    final textCtrl = TextEditingController(text: s.text);
    final mediaCtrl = TextEditingController(text: s.mediaUrl);
    final choicesCtrl = TextEditingController(text: s.choices.join('\n'));
    final answerCtrl = TextEditingController(text: s.answer);
    final numberCtrl = TextEditingController(text: s.number > 0 ? '${s.number}' : '');
    var timer = s.timerSeconds;
    var kind = s.quizKind;
    final c = context.c;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.bgElevated,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: AppRadius.r24)),
      builder: (sc) => StatefulBuilder(
        builder: (sctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(AppSpace.s20, AppSpace.s20, AppSpace.s20, MediaQuery.of(sctx).viewInsets.bottom + AppSpace.s24),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(s.type.label, style: AppType.title3),
              Text(s.type.category.label, style: AppType.caption1.copyWith(color: c.labelAlt)),
              const SizedBox(height: AppSpace.s16),
              TextField(
                controller: textCtrl,
                maxLines: s.type == LessonSlideType.title ? 1 : 3,
                style: AppType.body1.copyWith(color: c.labelNormal),
                decoration: _dec(c, _textHint(s.type)),
              ),
              if (s.type.hasMedia) ...[
                const SizedBox(height: AppSpace.s12),
                TextField(controller: mediaCtrl, style: AppType.body2.copyWith(color: c.labelNormal), decoration: _dec(c, '${s.type.label} URL (https://…)')),
              ],
              if (s.type == LessonSlideType.timer) ...[
                const SizedBox(height: AppSpace.s12),
                Wrap(spacing: AppSpace.s8, children: [
                  for (final m in [3, 5, 10])
                    ChoiceChip(label: Text('$m분'), selected: timer == m * 60, onSelected: (_) => setSheet(() => timer = m * 60)),
                ]),
              ] else if (s.type.hasNumber) ...[
                const SizedBox(height: AppSpace.s12),
                TextField(
                  controller: numberCtrl,
                  keyboardType: TextInputType.number,
                  style: AppType.body2.copyWith(color: c.labelNormal),
                  decoration: _dec(c, '숫자 (${s.type.numberUnit})'),
                ),
              ],
              if (s.type.hasChoices) ...[
                const SizedBox(height: AppSpace.s12),
                if (s.type == LessonSlideType.quiz || s.type == LessonSlideType.quizBattle)
                  Wrap(spacing: AppSpace.s8, children: [
                    for (final k in QuizKind.values)
                      ChoiceChip(label: Text(k.label), selected: kind == k, onSelected: (_) => setSheet(() => kind = k)),
                  ]),
                const SizedBox(height: AppSpace.s8),
                TextField(controller: choicesCtrl, maxLines: 4, style: AppType.body2.copyWith(color: c.labelNormal), decoration: _dec(c, '보기 / 항목 (줄마다 하나)')),
                const SizedBox(height: AppSpace.s8),
                TextField(controller: answerCtrl, style: AppType.body2.copyWith(color: c.labelNormal), decoration: _dec(c, '정답 (선택)')),
              ],
              const SizedBox(height: AppSpace.s20),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: c.accent, minimumSize: const Size.fromHeight(48)),
                onPressed: () {
                  setState(() {
                    _slides[i] = s.copyWith(
                      text: textCtrl.text.trim(),
                      mediaUrl: mediaCtrl.text.trim(),
                      timerSeconds: timer,
                      number: int.tryParse(numberCtrl.text.trim()) ?? s.number,
                      quizKind: kind,
                      choices: choicesCtrl.text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
                      answer: answerCtrl.text.trim(),
                    );
                  });
                  Navigator.pop(sc);
                },
                child: const Text('적용'),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  String _textHint(LessonSlideType t) => switch (t) {
        LessonSlideType.title => '제목',
        LessonSlideType.description => '설명 내용',
        LessonSlideType.question => '질문 (학생 답변을 기록해요)',
        LessonSlideType.ideaBoard => '아이디어보드 안내 (학생이 포스트잇으로 답해요)',
        LessonSlideType.exitTicket => '한 줄 요약 질문 (예: 오늘 알게 된 것은?)',
        LessonSlideType.aiSummary => 'AI 요약 안내 (학생 답변을 AI가 요약해요)',
        _ => '내용 / 안내 문구',
      };

  Future<String?> _promptText(String title, String hint) {
    final ctrl = TextEditingController();
    final c = context.c;
    return showDialog<String>(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: c.bgElevated,
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 2,
          decoration: InputDecoration(hintText: hint),
          onSubmitted: (v) => Navigator.pop(dctx, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dctx), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(dctx, ctrl.text.trim()), child: const Text('확인')),
        ],
      ),
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
