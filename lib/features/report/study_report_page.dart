import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/account_providers.dart';
import '../../app/app_providers.dart';
import '../../app/assignment_providers.dart';
import '../../app/classroom_providers.dart';
import '../../app/flashcard_providers.dart';
import '../../app/study_report_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/ai/gemini_service.dart';
import '../../domain/classroom/classroom.dart';
import '../../domain/report/study_report.dart';
import '../../domain/report/study_report_template.dart';
import '../../domain/study/study_mode.dart';
import '../../shared/widgets/ui.dart';

/// 학생: 오늘 학습 기록(스터디 플래너) 작성 — 자동 생성 → 수정 → 임시저장/제출.
class StudyReportPage extends ConsumerStatefulWidget {
  const StudyReportPage({super.key});
  @override
  ConsumerState<StudyReportPage> createState() => _StudyReportPageState();
}

class _StudyReportPageState extends ConsumerState<StudyReportPage> {
  final _content = TextEditingController();
  final _subject = TextEditingController();
  final _today = DateTime.now();

  StudySummary _summary = const StudySummary();
  String _studentName = '';
  String _teacherUid = '';
  String _teacherName = '';
  String? _reportId;
  bool _busy = false;
  bool _generating = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _content.dispose();
    _subject.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    _summary = _buildSummary();
    _subject.text = _summary.primarySubject;
    _studentName = ref.read(currentProfileProvider).value?.displayName ?? '';
    // 교실 가입이 곧 교사 연결 — 내 교실 구성원(학생) 중 첫 교실의 담당 교사에게 제출.
    final memberships = ref.read(myClassroomsProvider).value ?? const <ClassroomMember>[];
    final asStudent = memberships.where((m) => m.role == ClassroomRole.student).toList();
    if (asStudent.isNotEmpty) {
      _teacherUid = asStudent.first.teacherUid;
      final teacher = await ref.read(accountRepositoryProvider).loadProfile(_teacherUid);
      _teacherName = teacher?.displayName ?? asStudent.first.classroomName;
    }
    await _generate();
  }

  /// 오늘의 학습 데이터를 모아 요약 스냅샷을 만든다(기존 provider 들에서 파생).
  StudySummary _buildSummary() {
    final app = ref.read(appProvider);
    bool isToday(DateTime d) => d.year == _today.year && d.month == _today.month && d.day == _today.day;

    final today = app.sessions.where((s) => isToday(s.date)).toList();
    final subjects = <String>{for (final s in today) s.subject}.toList();
    final didBlank = today.any((s) => s.mode == StudyMode.blank);
    final quizzes = today.where((s) => s.accuracy != null).toList();
    final quizAcc = quizzes.isEmpty
        ? null
        : (quizzes.map((s) => s.accuracy!).reduce((a, b) => a + b) / quizzes.length).round();

    final progress = ref.read(myFlashcardProgressProvider).value ?? const {};
    var reviewed = 0;
    for (final p in progress.values) {
      for (final r in p.reviews.values) {
        if (r.lastReviewedAt != null && isToday(r.lastReviewedAt!)) reviewed++;
      }
    }

    final subs = ref.read(mySubmissionsProvider).value ?? const {};
    final done = subs.values.where((s) => s.isDone).length;

    return StudySummary(
      studyMinutes: app.growth.todayMin,
      subjects: subjects,
      sessionCount: today.length,
      didBlankReview: didBlank,
      quizAccuracy: quizAcc,
      reviewedCards: reviewed,
      assignmentsDone: done,
    );
  }

  Future<void> _generate() async {
    setState(() => _generating = true);
    final ai = await GeminiService.generateStudyReportDraft(_summary);
    final text = ai ?? StudyReportTemplate.compose(_summary);
    if (!mounted) return;
    setState(() {
      _content.text = text;
      _generating = false;
    });
  }

  StudyReport _current() => StudyReport(
        id: _reportId ?? '',
        studentUid: '',
        teacherUid: _teacherUid,
        studentName: _studentName,
        subject: _subject.text.trim(),
        studyMinutes: _summary.studyMinutes,
        content: _content.text.trim(),
      );

  Future<void> _ensureCreated() async {
    if (_reportId != null) return;
    final r = await ref.read(studyReportRepositoryProvider).createDraft(
          studentName: _studentName,
          teacherUid: _teacherUid,
          subject: _subject.text.trim(),
          studyMinutes: _summary.studyMinutes,
          content: _content.text.trim(),
        );
    _reportId = r.id;
  }

  Future<void> _saveDraft() async {
    setState(() => _busy = true);
    try {
      if (_reportId == null) {
        await _ensureCreated();
      } else {
        await ref.read(studyReportRepositoryProvider).saveDraft(_current());
      }
      if (mounted) {
        FocusScope.of(context).unfocus();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('임시 저장했어요.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      await _ensureCreated();
      await ref.read(studyReportRepositoryProvider).submitReport(_current());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_teacherUid.isEmpty
              ? '기록을 저장했어요. (연결된 선생님이 없어요)'
              : '$_teacherName 선생님께 제출했어요.'),
        ));
        context.pop();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final dateLabel =
        '${_today.year}.${_today.month.toString().padLeft(2, '0')}.${_today.day.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => context.pop()),
        title: Text('오늘 학습 기록', style: AppType.headline1),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpace.s20),
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 16, color: c.labelAlt),
                      const SizedBox(width: 6),
                      Text(dateLabel, style: AppType.body2.copyWith(color: c.labelAlt)),
                      if (_teacherName.isNotEmpty) ...[
                        const Spacer(),
                        Text('$_teacherName 선생님', style: AppType.body2.copyWith(color: c.labelAlt)),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpace.s16),
                  const SectionLabel('과목'),
                  TextField(
                    controller: _subject,
                    style: AppType.body1.copyWith(color: c.labelNormal),
                    decoration: _dec(c, '과목'),
                  ),
                  const SizedBox(height: AppSpace.s16),
                  Row(
                    children: [
                      const SectionLabel('학습 내용'),
                      const Spacer(),
                      Text('총 ${_summary.studyMinutes}분', style: AppType.caption1.copyWith(color: c.labelAssistive)),
                    ],
                  ),
                  const SizedBox(height: AppSpace.s8),
                  if (_generating)
                    Container(
                      height: 200,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c.bgElevated,
                        borderRadius: AppRadius.b14,
                        border: Border.all(color: c.lineAlt),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: c.accent),
                          const SizedBox(height: AppSpace.s12),
                          Text('학습 기록을 작성하고 있어요…', style: AppType.body2.copyWith(color: c.labelAlt)),
                        ],
                      ),
                    )
                  else
                    TextField(
                      controller: _content,
                      maxLines: null,
                      minLines: 8,
                      style: AppType.body1.copyWith(color: c.labelNormal, height: 1.5),
                      decoration: _dec(c, '오늘의 학습을 적어보세요'),
                    ),
                  const SizedBox(height: AppSpace.s12),
                  OutlinedButton.icon(
                    onPressed: _generating || _busy ? null : _generate,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('초안 다시 생성'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: c.accent,
                      side: BorderSide(color: c.lineAlt),
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.b14),
                      padding: const EdgeInsets.symmetric(vertical: AppSpace.s12),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.s20, 0, AppSpace.s20, AppSpace.s12),
              child: Row(
                children: [
                  Expanded(
                    child: OclButton('임시 저장', ghost: true, onPressed: _busy || _generating ? null : _saveDraft),
                  ),
                  const SizedBox(width: AppSpace.s10),
                  Expanded(
                    child: OclButton('선생님께 제출', onPressed: _busy || _generating ? null : _submit),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _dec(AppColors c, String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: c.bgElevated,
        enabledBorder:
            OutlineInputBorder(borderRadius: AppRadius.b14, borderSide: BorderSide(color: c.lineAlt)),
        focusedBorder: OutlineInputBorder(
            borderRadius: AppRadius.b14, borderSide: BorderSide(color: c.accent, width: 2)),
        contentPadding: const EdgeInsets.all(AppSpace.s16),
      );
}
