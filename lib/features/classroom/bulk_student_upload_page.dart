import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/classroom_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/ai/gemini_service.dart';
import '../../data/firebase/bulk_student_repository.dart';
import '../../data/roster/roster_file_parser.dart';
import '../../data/roster/roster_file_picker.dart';
import '../../domain/account/roster.dart';
import '../../shared/widgets/ui.dart';

enum _Phase { input, preview, creating, done }

/// P8-3 — 교사: 파일 업로드 → Gemini 이름 추출 → 미리보기 → 학생 일괄 생성.
class BulkStudentUploadPage extends ConsumerStatefulWidget {
  final String classroomId;
  final String? classroomName;
  const BulkStudentUploadPage({super.key, required this.classroomId, this.classroomName});

  @override
  ConsumerState<BulkStudentUploadPage> createState() => _BulkStudentUploadPageState();
}

class _BulkStudentUploadPageState extends ConsumerState<BulkStudentUploadPage> {
  _Phase _phase = _Phase.input;

  final _pasteCtrl = TextEditingController();
  final _domainCtrl = TextEditingController(text: RosterBuilder.defaultDomain);
  final _pwCtrl = TextEditingController();
  final _pwConfirmCtrl = TextEditingController();

  String _rawText = '';
  String? _fileName;
  List<TextEditingController> _nameCtrls = [];

  bool _busy = false;
  String? _error;
  int _done = 0;
  int _total = 0;
  BulkCreateSummary? _summary;

  @override
  void dispose() {
    _pasteCtrl.dispose();
    _domainCtrl.dispose();
    _pwCtrl.dispose();
    _pwConfirmCtrl.dispose();
    _disposeNameCtrls();
    super.dispose();
  }

  void _disposeNameCtrls() {
    for (final c in _nameCtrls) {
      c.dispose();
    }
    _nameCtrls = [];
  }

  String get _className => widget.classroomName?.isNotEmpty == true ? widget.classroomName! : '교실';

  List<RosterEntry> _roster() => RosterBuilder.build(
        _nameCtrls.map((c) => c.text).toList(),
        domain: _domainCtrl.text,
      );

  // ---- 1) 입력: 파일 선택 또는 붙여넣기 ----
  Future<void> _pickFile() async {
    setState(() => _error = null);
    try {
      final picked = await pickRosterFile();
      if (picked == null) return; // 취소
      if (!RosterFileParser.supportedExtensions.contains(RosterFileParser.extensionOf(picked.name))) {
        setState(() => _error = 'xlsx · csv · txt 파일만 지원해요.');
        return;
      }
      _rawText = RosterFileParser.parse(filename: picked.name, bytes: picked.bytes);
      _fileName = picked.name;
      await _extract();
    } catch (_) {
      if (mounted) setState(() => _error = '파일을 읽지 못했어요. 형식을 확인해주세요.');
    }
  }

  Future<void> _extractFromPaste() async {
    _rawText = _pasteCtrl.text;
    _fileName = null;
    await _extract();
  }

  Future<void> _extract() async {
    if (_rawText.trim().isEmpty) {
      setState(() => _error = '파일을 선택하거나 명단을 붙여넣어 주세요.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    // Gemini 우선, 실패 시 결정적 휴리스틱.
    List<String> names;
    final gem = await GeminiService.extractStudentRoster(_rawText);
    names = (gem != null && gem.isNotEmpty)
        ? gem.map((e) => e.name).toList()
        : RosterBuilder.extractNames(_rawText);
    // 공백/중복 정리.
    final seen = <String>{};
    final clean = <String>[];
    for (final n in names) {
      final t = n.trim();
      if (t.isNotEmpty && seen.add(t)) clean.add(t);
    }
    if (!mounted) return;
    if (clean.isEmpty) {
      setState(() {
        _busy = false;
        _error = '이름을 찾지 못했어요. 명단 형식을 확인해주세요.';
      });
      return;
    }
    _disposeNameCtrls();
    _nameCtrls = clean.map((n) => TextEditingController(text: n)).toList();
    setState(() {
      _busy = false;
      _phase = _Phase.preview;
    });
  }

  // ---- 2) 생성 ----
  Future<void> _create() async {
    final roster = _roster();
    if (roster.isEmpty) {
      setState(() => _error = '학생이 없어요.');
      return;
    }
    final pw = _pwCtrl.text;
    if (pw.length < 6) {
      setState(() => _error = '임시 비밀번호는 6자 이상이어야 해요.');
      return;
    }
    if (pw != _pwConfirmCtrl.text) {
      setState(() => _error = '비밀번호 확인이 일치하지 않아요.');
      return;
    }
    setState(() {
      _phase = _Phase.creating;
      _done = 0;
      _total = roster.length;
      _error = null;
    });
    try {
      final summary = await ref.read(bulkStudentRepositoryProvider).createStudents(
            entries: roster,
            password: pw,
            classroomId: widget.classroomId,
            classroomName: widget.classroomName ?? '',
            onProgress: (d, t) {
              if (mounted) setState(() => _done = d);
            },
          );
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _phase = _Phase.done;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.preview;
        _error = '생성에 실패했어요. 잠시 후 다시 시도해주세요.';
      });
    }
  }

  void _removeRow(int i) {
    final c = _nameCtrls.removeAt(i);
    c.dispose();
    setState(() {});
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
        titleSpacing: 0,
        leading: IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => context.pop()),
        title: Text('$_className · 학생 일괄 등록', style: AppType.headline1),
      ),
      body: SafeArea(
        child: switch (_phase) {
          _Phase.input => _inputView(c),
          _Phase.preview => _previewView(c),
          _Phase.creating => _creatingView(c),
          _Phase.done => _doneView(c),
        },
      ),
    );
  }

  // ============================ Views ============================

  Widget _inputView(AppColors c) {
    return ListView(
      padding: const EdgeInsets.all(AppSpace.s20),
      children: [
        Text('명단 파일을 올리면 AI가 이름을 자동으로 인식해요.',
            style: AppType.body1.copyWith(color: c.labelNeutral)),
        const SizedBox(height: 4),
        Text('지원 형식: 엑셀(xlsx) · CSV · 텍스트(txt)', style: AppType.body2.copyWith(color: c.labelAlt)),
        const SizedBox(height: AppSpace.s20),
        if (rosterPickerSupported)
          OclCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Icon(Icons.upload_file_outlined, color: c.accent),
                const SizedBox(width: AppSpace.s8),
                Text('파일 업로드', style: AppType.headline2),
              ]),
              const SizedBox(height: AppSpace.s12),
              OclButton(_busy ? '인식 중…' : '파일 선택', onPressed: _busy ? null : _pickFile),
              if (_fileName != null) ...[
                const SizedBox(height: AppSpace.s8),
                Text('선택됨: $_fileName', style: AppType.caption1.copyWith(color: c.labelAlt)),
              ],
            ]),
          )
        else
          OclCard(
            color: c.accentSoft,
            child: Text('파일 업로드는 웹에서 지원돼요. 모바일에선 아래에 명단을 붙여넣어 주세요.',
                style: AppType.body2.copyWith(color: c.labelNeutral)),
          ),
        const SizedBox(height: AppSpace.s16),
        Row(children: [
          Expanded(child: Divider(color: c.lineAlt)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.s12),
            child: Text('또는 직접 붙여넣기', style: AppType.caption1.copyWith(color: c.labelAssistive)),
          ),
          Expanded(child: Divider(color: c.lineAlt)),
        ]),
        const SizedBox(height: AppSpace.s16),
        TextField(
          controller: _pasteCtrl,
          maxLines: 8,
          style: AppType.body1.copyWith(color: c.labelNormal),
          decoration: InputDecoration(
            hintText: '김철수\n이영희\n박민수',
            filled: true,
            fillColor: c.bgElevated,
            enabledBorder: OutlineInputBorder(borderRadius: AppRadius.b14, borderSide: BorderSide(color: c.lineAlt)),
            focusedBorder: OutlineInputBorder(borderRadius: AppRadius.b14, borderSide: BorderSide(color: c.accent, width: 2)),
            contentPadding: const EdgeInsets.all(AppSpace.s16),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpace.s12),
          Text(_error!, style: AppType.body2.copyWith(color: c.negative)),
        ],
        const SizedBox(height: AppSpace.s16),
        OclButton(_busy ? '인식 중…' : '이름 추출', ghost: true, onPressed: _busy ? null : _extractFromPaste),
      ],
    );
  }

  Widget _previewView(AppColors c) {
    final roster = _roster();
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpace.s20),
            children: [
              Text('인식된 학생 ${roster.length}명', style: AppType.title3.copyWith(color: c.labelStrong)),
              const SizedBox(height: 4),
              Text('이름을 확인·수정하고, 모두에게 적용할 임시 비밀번호를 정하세요.',
                  style: AppType.body2.copyWith(color: c.labelAlt)),
              const SizedBox(height: AppSpace.s16),
              Row(children: [
                Expanded(
                  flex: 2,
                  child: _smallField(c, _pwCtrl, '임시 비밀번호 (6자+)', obscure: true),
                ),
                const SizedBox(width: AppSpace.s8),
                Expanded(
                  flex: 2,
                  child: _smallField(c, _pwConfirmCtrl, '비밀번호 확인', obscure: true),
                ),
              ]),
              const SizedBox(height: AppSpace.s8),
              _smallField(c, _domainCtrl, '이메일 도메인', onChanged: (_) => setState(() {})),
              if (_error != null) ...[
                const SizedBox(height: AppSpace.s12),
                Text(_error!, style: AppType.body2.copyWith(color: c.negative)),
              ],
              const SizedBox(height: AppSpace.s16),
              for (var i = 0; i < _nameCtrls.length; i++) _row(c, i, roster),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.s20, AppSpace.s8, AppSpace.s20, AppSpace.s12),
            child: OclButton('학생 ${roster.length}명 생성', onPressed: roster.isEmpty ? null : _create),
          ),
        ),
      ],
    );
  }

  Widget _row(AppColors c, int i, List<RosterEntry> roster) {
    final email = i < roster.length ? roster[i].email : '';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s8),
      child: OclCard(
        padding: const EdgeInsets.fromLTRB(AppSpace.s12, AppSpace.s8, AppSpace.s4, AppSpace.s8),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(
                controller: _nameCtrls[i],
                style: AppType.body1.copyWith(color: c.labelNormal),
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  hintText: '이름',
                ),
              ),
              Text(email, style: AppType.caption1.copyWith(color: c.labelAlt)),
            ]),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 20, color: c.labelAssistive),
            onPressed: () => _removeRow(i),
          ),
        ]),
      ),
    );
  }

  Widget _creatingView(AppColors c) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircularProgressIndicator(color: c.accent),
        const SizedBox(height: AppSpace.s16),
        Text('$_done / $_total 생성 중…', style: AppType.headline2.copyWith(color: c.labelNeutral)),
        const SizedBox(height: 4),
        Text('계정을 만들고 교실에 등록하고 있어요.', style: AppType.body2.copyWith(color: c.labelAlt)),
      ]),
    );
  }

  Widget _doneView(AppColors c) {
    final s = _summary;
    final created = s?.created ?? 0;
    final failures = s?.failures ?? const <BulkCreateResult>[];
    return ListView(
      padding: const EdgeInsets.all(AppSpace.s24),
      children: [
        const SizedBox(height: AppSpace.s12),
        Center(
          child: Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.accentSoft, borderRadius: AppRadius.b20),
            child: Icon(Icons.check_rounded, size: 36, color: c.accent),
          ),
        ),
        const SizedBox(height: AppSpace.s20),
        Text('$created명의 학생이 생성되었고\n$_className에 자동 등록되었습니다.',
            textAlign: TextAlign.center, style: AppType.title3.copyWith(color: c.labelStrong)),
        const SizedBox(height: AppSpace.s8),
        Text('학생은 발급된 이메일과 임시 비밀번호로 로그인한 뒤,\n첫 화면에서 새 비밀번호를 직접 설정해요.',
            textAlign: TextAlign.center, style: AppType.body2.copyWith(color: c.labelAlt)),
        if (failures.isNotEmpty) ...[
          const SizedBox(height: AppSpace.s20),
          OclCard(
            color: c.bgAlt,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${failures.length}명은 건너뛰었어요', style: AppType.headline2.copyWith(color: c.cautionary)),
              const SizedBox(height: AppSpace.s8),
              for (final f in failures)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text('· ${f.name} (${f.email}) — ${_reason(f.error)}',
                      style: AppType.caption1.copyWith(color: c.labelAlt)),
                ),
            ]),
          ),
        ],
        const SizedBox(height: AppSpace.s24),
        OclButton('완료', onPressed: () => context.pop()),
      ],
    );
  }

  String _reason(String? code) => switch (code) {
        'email-already-in-use' => '이미 가입된 이메일',
        'invalid-email' => '이메일 형식 오류',
        'weak-password' => '비밀번호가 약함',
        'enroll-failed' => '교실 등록 실패',
        _ => '생성 실패',
      };

  Widget _smallField(AppColors c, TextEditingController ctrl, String hint,
      {bool obscure = false, ValueChanged<String>? onChanged}) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      autocorrect: false,
      enableSuggestions: false,
      onChanged: onChanged,
      style: AppType.body2.copyWith(color: c.labelNormal),
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        filled: true,
        fillColor: c.bgElevated,
        enabledBorder: OutlineInputBorder(borderRadius: AppRadius.b12, borderSide: BorderSide(color: c.lineAlt)),
        focusedBorder: OutlineInputBorder(borderRadius: AppRadius.b12, borderSide: BorderSide(color: c.accent, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.s12, vertical: AppSpace.s12),
      ),
    );
  }
}
