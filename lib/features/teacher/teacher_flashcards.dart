import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/account_providers.dart';
import '../../app/classroom_providers.dart';
import '../../app/flashcard_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/ocr/ocr_service.dart';
import '../../domain/classroom/classroom.dart';
import '../../domain/flashcard/flashcard_deck.dart';
import '../../domain/vocab/vocab_word.dart';
import '../../shared/widgets/ui.dart';

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

InputDecoration _dec(AppColors c, String hint) => InputDecoration(
      hintText: hint,
      isDense: true,
      filled: true,
      fillColor: c.bgElevated,
      enabledBorder: OutlineInputBorder(borderRadius: AppRadius.b14, borderSide: BorderSide(color: c.lineAlt)),
      focusedBorder: OutlineInputBorder(borderRadius: AppRadius.b14, borderSide: BorderSide(color: c.accent, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.s16, vertical: AppSpace.s14),
    );

/// 선생님 · 플래시카드 덱 목록 (탭).
class TeacherFlashcardsPage extends ConsumerWidget {
  const TeacherFlashcardsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final async = ref.watch(teacherDecksProvider);
    return Scaffold(
      appBar: _bar(context, '플래시 카드'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/t/flashcards/new'),
        backgroundColor: c.accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('카드 만들기'),
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
                  itemBuilder: (_, i) => _TeacherDeckRow(deck: list[i]),
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
            Icon(Icons.style_outlined, size: 48, color: c.labelAssistive),
            const SizedBox(height: AppSpace.s12),
            Text('아직 만든 카드가 없어요.\n직접 입력하거나 단어장을 촬영해 만들어 보세요.',
                textAlign: TextAlign.center, style: AppType.body1.copyWith(color: c.labelAlt)),
          ],
        ),
      ),
    );
  }
}

/// 덱 목록 한 행 — 제목·과목·카드 수 + 완료 학생 수(실시간).
class _TeacherDeckRow extends ConsumerWidget {
  final FlashcardDeck deck;
  const _TeacherDeckRow({required this.deck});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final prog = ref.watch(progressForDeckProvider(deck.id)).value ?? const {};
    final total = deck.studentUids.length;
    final done = deck.studentUids.where((u) => prog[u]?.isDone ?? false).length;
    final allDone = total > 0 && done == total;

    return InkWell(
      borderRadius: AppRadius.b16,
      onTap: () => context.push('/t/flashcards/detail', extra: deck),
      child: OclCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(deck.title, style: AppType.headline2)),
                if (deck.fromOcr)
                  Padding(
                    padding: const EdgeInsets.only(left: AppSpace.s8),
                    child: Icon(Icons.photo_camera_outlined, size: 16, color: c.labelAssistive),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    [if (deck.subject?.isNotEmpty ?? false) deck.subject!, '카드 ${deck.cardCount}장', '학생 $total명']
                        .join(' · '),
                    style: AppType.body2.copyWith(color: c.labelAlt),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.s8, vertical: 3),
                  decoration: BoxDecoration(
                    color: allDone ? c.accentSoft : c.fill,
                    borderRadius: AppRadius.bFull,
                  ),
                  child: Text('완료 $done/$total',
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

/// 카드 1장 작성용 임시 모델(자체 컨트롤러 소유).
class _CardDraft {
  final TextEditingController front;
  final TextEditingController back;
  final TextEditingController example;
  final TextEditingController hint;
  bool extra; // 예문·힌트 펼침 여부

  _CardDraft({String front = '', String back = '', String example = '', String hint = ''})
      : front = TextEditingController(text: front),
        back = TextEditingController(text: back),
        example = TextEditingController(text: example),
        hint = TextEditingController(text: hint),
        extra = example.isNotEmpty || hint.isNotEmpty;

  bool get isEmpty => front.text.trim().isEmpty && back.text.trim().isEmpty;
  bool get isValid => front.text.trim().isNotEmpty && back.text.trim().isNotEmpty;

  void dispose() {
    front.dispose();
    back.dispose();
    example.dispose();
    hint.dispose();
  }
}

/// 선생님 · 덱 생성(직접 입력 + OCR).
class TeacherDeckCreatePage extends ConsumerStatefulWidget {
  const TeacherDeckCreatePage({super.key});
  @override
  ConsumerState<TeacherDeckCreatePage> createState() => _CreateState();
}

class _CreateState extends ConsumerState<TeacherDeckCreatePage> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _subject = TextEditingController();
  final _bulk = TextEditingController();
  final List<_CardDraft> _drafts = [];
  final Set<String> _selected = {};
  bool _fromOcr = false;
  bool _saving = false;
  bool _scanning = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _subject.dispose();
    _bulk.dispose();
    for (final d in _drafts) {
      d.dispose();
    }
    super.dispose();
  }

  /// 일괄 입력 박스의 텍스트("front - back" 한 줄에 하나)를 파싱해 카드로 추가.
  void _addFromBulk() {
    final pairs = VocabWord.parseLines(_bulk.text);
    if (pairs.isEmpty) {
      setState(() => _error = '인식된 카드가 없어요. "단어 - 뜻" 형식으로 한 줄에 하나씩 입력해주세요.');
      return;
    }
    setState(() {
      for (final p in pairs) {
        _drafts.add(_CardDraft(front: p.term, back: p.meaning));
      }
      _bulk.clear();
      _error = null;
    });
  }

  Future<void> _scan(ImageSource source) async {
    setState(() {
      _scanning = true;
      _error = null;
    });
    try {
      final text = await OcrService.scanRawText(source);
      if (text == null) return; // 취소
      if (text.trim().isEmpty) {
        setState(() => _error = '사진에서 글자를 찾지 못했어요. 더 밝고 또렷한 사진으로 다시 시도해주세요.');
        return;
      }
      setState(() {
        // 인식 결과를 일괄 입력 박스에 채워 사용자가 검토·수정 후 ‘카드로 추가’.
        _bulk.text = text.trim();
        _fromOcr = true;
      });
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) return setState(() => _error = '제목을 입력해주세요.');
    final cards = _drafts.where((d) => d.isValid).toList();
    if (cards.isEmpty) return setState(() => _error = '앞/뒤가 모두 채워진 카드가 한 장 이상 필요해요.');
    if (_selected.isEmpty) return setState(() => _error = '배포할 학생을 한 명 이상 선택해주세요.');
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final profile = ref.read(currentProfileProvider).value;
      await ref.read(flashcardRepositoryProvider).createDeck(
            teacherName: profile?.displayName ?? '',
            title: _title.text.trim(),
            description: _desc.text.trim(),
            subject: _subject.text.trim().isEmpty ? null : _subject.text.trim(),
            cards: cards
                .map((d) => Flashcard(
                      id: '',
                      deckId: '',
                      front: d.front.text.trim(),
                      back: d.back.text.trim(),
                      example: d.example.text.trim(),
                      hint: d.hint.text.trim(),
                    ))
                .toList(),
            studentUids: _selected.toList(),
            fromOcr: _fromOcr,
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
    final validCount = _drafts.where((d) => d.isValid).length;

    return Scaffold(
      appBar: _bar(context, '카드 만들기', back: true),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpace.s24),
          children: [
            TextField(controller: _title, style: AppType.body1.copyWith(color: c.labelNormal), decoration: _dec(c, '제목 (예: 중1 영단어 Day 1)')),
            const SizedBox(height: AppSpace.s10),
            TextField(controller: _desc, maxLines: 2, style: AppType.body1.copyWith(color: c.labelNormal), decoration: _dec(c, '설명 (선택)')),
            const SizedBox(height: AppSpace.s10),
            TextField(controller: _subject, style: AppType.body1.copyWith(color: c.labelNormal), decoration: _dec(c, '과목 (선택, 예: 영어)')),
            const SizedBox(height: AppSpace.s20),

            // ---- 카드 추가(직접 입력 + OCR) ----
            const SectionLabel('카드 추가'),
            TextField(
              controller: _bulk,
              maxLines: 4,
              style: AppType.body1.copyWith(color: c.labelNormal),
              decoration: _dec(c, '단어 - 뜻 (한 줄에 하나)\nabandon - 버리다\nobstacle - 장애물'),
            ),
            const SizedBox(height: AppSpace.s8),
            Row(
              children: [
                Expanded(child: OclButton('카드로 추가', ghost: true, onPressed: _addFromBulk)),
                const SizedBox(width: AppSpace.s8),
                _ocrButton(c),
              ],
            ),
            if (_fromOcr)
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.s8),
                child: Text('사진에서 인식한 텍스트예요. 틀린 부분을 고친 뒤 ‘카드로 추가’를 눌러주세요.',
                    style: AppType.caption1.copyWith(color: c.labelAlt)),
              ),
            const SizedBox(height: AppSpace.s20),

            // ---- 카드 목록(편집) ----
            SectionLabel('카드 ($validCount장)'),
            if (_drafts.isEmpty)
              Text('아직 카드가 없어요. 위에서 추가해주세요.', style: AppType.body2.copyWith(color: c.labelAlt))
            else
              ...List.generate(_drafts.length, (i) => _cardEditor(c, i)),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _drafts.add(_CardDraft())),
                icon: Icon(Icons.add, size: 18, color: c.accent),
                label: Text('빈 카드 추가', style: AppType.label1.copyWith(color: c.accent)),
              ),
            ),
            const SizedBox(height: AppSpace.s12),

            // ---- 배포 대상 ----
            SectionLabel('배포 대상 (${_selected.length}/${students.length})'),
            if (students.isEmpty)
              Text('교실에 추가된 학생이 없어요. ‘교실’에서 학생을 먼저 추가해주세요.',
                  style: AppType.body2.copyWith(color: c.labelAlt))
            else
              ...students.map((l) => _studentCheck(c, l)),

            if (_error != null) ...[
              const SizedBox(height: AppSpace.s12),
              Text(_error!, style: AppType.body2.copyWith(color: c.negative)),
            ],
            const SizedBox(height: AppSpace.s24),
            _saving
                ? Center(child: CircularProgressIndicator(color: c.accent))
                : OclButton('카드 배포하기', onPressed: _save),
          ],
        ),
      ),
    );
  }

  Widget _ocrButton(AppColors c) {
    if (!OcrService.supported) {
      return Tooltip(
        message: '이 기기에서는 카메라 OCR을 지원하지 않아요',
        child: Opacity(
          opacity: 0.4,
          child: _ocrBox(c, Icons.photo_camera_outlined, null),
        ),
      );
    }
    if (_scanning) return _ocrBox(c, null, null, busy: true);
    return _ocrBox(c, Icons.photo_camera_outlined, _pickSource);
  }

  Widget _ocrBox(AppColors c, IconData? icon, VoidCallback? onTap, {bool busy = false}) {
    return SizedBox(
      width: 56,
      height: 56,
      child: Material(
        color: c.fill,
        borderRadius: AppRadius.b16,
        child: InkWell(
          borderRadius: AppRadius.b16,
          onTap: onTap,
          child: Center(
            child: busy
                ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: c.accent))
                : Icon(icon, color: c.labelNeutral),
          ),
        ),
      ),
    );
  }

  Future<void> _pickSource() async {
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('사진 촬영'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('갤러리에서 선택'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (src != null) await _scan(src);
  }

  Widget _cardEditor(AppColors c, int i) {
    final d = _drafts[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s8),
      child: OclCard(
        child: Column(
          children: [
            Row(
              children: [
                Text('${i + 1}', style: AppType.label2.copyWith(color: c.labelAlt)),
                const SizedBox(width: AppSpace.s12),
                Expanded(child: TextField(controller: d.front, style: AppType.body1.copyWith(color: c.labelNormal), decoration: _dec(c, '앞면'))),
                const SizedBox(width: AppSpace.s8),
                Expanded(child: TextField(controller: d.back, style: AppType.body1.copyWith(color: c.labelNormal), decoration: _dec(c, '뒷면'))),
                IconButton(
                  icon: Icon(Icons.close, size: 18, color: c.labelAssistive),
                  onPressed: () => setState(() => _drafts.removeAt(i).dispose()),
                ),
              ],
            ),
            if (d.extra) ...[
              const SizedBox(height: AppSpace.s8),
              TextField(controller: d.example, style: AppType.body2.copyWith(color: c.labelNormal), decoration: _dec(c, '예문 (선택)')),
              const SizedBox(height: AppSpace.s8),
              TextField(controller: d.hint, style: AppType.body2.copyWith(color: c.labelNormal), decoration: _dec(c, '힌트 (선택)')),
            ] else
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => setState(() => d.extra = true),
                  child: Text('예문·힌트 추가', style: AppType.caption1.copyWith(color: c.accent)),
                ),
              ),
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
              Icon(on ? Icons.check_circle : Icons.circle_outlined, size: 22, color: on ? c.accent : c.labelAssistive),
              const SizedBox(width: AppSpace.s12),
              Text(m.displayName.isEmpty ? '이름 미설정' : m.displayName, style: AppType.body1),
            ],
          ),
        ),
      ),
    );
  }
}

/// 선생님 · 덱 상세(카드 미리보기 + 학생별 학습 현황 실시간).
class TeacherDeckDetailPage extends ConsumerWidget {
  final FlashcardDeck deck;
  const TeacherDeckDetailPage({super.key, required this.deck});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final prog = ref.watch(progressForDeckProvider(deck.id)).value ?? const {};
    final cards = ref.watch(cardsForDeckProvider(deck.id)).value ?? const [];
    final names = {
      for (final m in (ref.watch(teacherStudentsProvider).value ?? const <ClassroomMember>[]))
        m.userUid: m.displayName,
    };
    final total = deck.studentUids.length;
    final done = deck.studentUids.where((u) => prog[u]?.isDone ?? false).length;

    return Scaffold(
      appBar: _bar(context, deck.title, back: true, actions: [
        IconButton(
          icon: Icon(Icons.delete_outline, color: c.labelAlt),
          onPressed: () => _confirmDelete(context, ref),
        ),
      ]),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpace.s20),
          children: [
            if (deck.description.isNotEmpty) ...[
              Text(deck.description, style: AppType.body1.copyWith(color: c.labelNeutral)),
              const SizedBox(height: AppSpace.s12),
            ],
            Text(
              [if (deck.subject?.isNotEmpty ?? false) deck.subject!, '카드 ${deck.cardCount}장', if (deck.fromOcr) 'OCR']
                  .join(' · '),
              style: AppType.body2.copyWith(color: c.labelAlt),
            ),
            const SizedBox(height: AppSpace.s16),
            OclCard(
              child: Row(
                children: [
                  Text('완료', style: AppType.headline2),
                  const Spacer(),
                  Text('$done / $total명', style: AppType.headline1.copyWith(color: c.accent)),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.s12),
            // 이 단어 세트로 즉시 경쟁전(학습 챌린지) 생성.
            OclButton('단어 경쟁전 만들기', onPressed: () => context.push('/battle/new', extra: deck)),
            const SizedBox(height: AppSpace.s20),
            const SectionLabel('학생별 현황'),
            ...deck.studentUids.map((u) {
              final p = prog[u];
              final name = (names[u] ?? p?.studentName ?? '').trim();
              return _studentStatus(context, name.isEmpty ? '이름 미설정' : name, p);
            }),
            const SizedBox(height: AppSpace.s20),
            const SectionLabel('카드 미리보기'),
            ...cards.map((card) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.s8),
                  child: OclCard(
                    child: Row(
                      children: [
                        Expanded(child: Text(card.front, style: AppType.body1.copyWith(fontWeight: FontWeight.w600))),
                        Expanded(child: Text(card.back, style: AppType.body2.copyWith(color: c.labelAlt))),
                      ],
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _studentStatus(BuildContext context, String name, FlashcardProgress? p) {
    final c = context.c;
    final status = p?.status ?? DeckStudyStatus.fresh;
    final (bg, fg) = switch (status) {
      DeckStudyStatus.done => (c.accentSoft, c.accent),
      DeckStudyStatus.learning => (c.fill, c.labelNeutral),
      DeckStudyStatus.fresh => (c.fill, c.labelAlt),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s8),
      child: OclCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(name, style: AppType.body1)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.s8, vertical: 3),
                  decoration: BoxDecoration(color: bg, borderRadius: AppRadius.bFull),
                  child: Text(status.label, style: AppType.caption1.copyWith(color: fg)),
                ),
              ],
            ),
            if (p != null && p.studiedCards > 0) ...[
              const SizedBox(height: 6),
              Text('정답률 ${p.correctPercent}% · 완료율 ${p.completionPercent}% · ${p.studyMinutes}분',
                  style: AppType.body2.copyWith(color: c.labelAlt)),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('덱을 삭제할까요?'),
        content: const Text('카드와 학생 학습 기록이 함께 삭제돼요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('삭제')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(flashcardRepositoryProvider).deleteDeck(deck.id);
      if (context.mounted) context.pop();
    }
  }
}
