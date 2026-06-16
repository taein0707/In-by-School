import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/report/study_report.dart';

/// 스터디 플래너(studyReports) — 학생이 작성·제출하고 선생님이 조회.
///
/// 숙제(assignments/submissions)와 동일 패턴:
///  - teacherUid 를 비정규화해 보안규칙이 get() 없이 평가.
///  - where(==) 만 쓰고 정렬은 메모리에서(복합 인덱스 회피).
class StudyReportRepository {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  String? get uid => _auth.currentUser?.uid;
  Future<String> ensureUser() async {
    if (_auth.currentUser == null) await _auth.signInAnonymously();
    return _auth.currentUser!.uid;
  }

  CollectionReference<Map<String, dynamic>> get _reports => _db.collection('studyReports');

  // ---- 학생: 초안 생성(자동 생성 본문을 담아 draft 로 저장) ----
  Future<StudyReport> createDraft({
    required String studentName,
    required String teacherUid,
    required String subject,
    required int studyMinutes,
    required String content,
  }) async {
    final studentUid = await ensureUser();
    final ref = _reports.doc();
    final now = DateTime.now();
    final report = StudyReport(
      id: ref.id,
      studentUid: studentUid,
      teacherUid: teacherUid,
      studentName: studentName,
      subject: subject,
      studyMinutes: studyMinutes,
      content: content,
      status: ReportStatus.draft,
      createdAt: now,
      updatedAt: now,
    );
    await ref.set(report.toMap());
    return report;
  }

  // ---- 학생: 임시 저장(본문/과목 갱신, 상태는 draft 유지) ----
  Future<void> saveDraft(StudyReport report) async {
    await _reports.doc(report.id).set({
      'subject': report.subject,
      'studyMinutes': report.studyMinutes,
      'content': report.content,
      'status': ReportStatus.draft.name,
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
  }

  // ---- 학생: 선생님께 제출(상태 submitted + 제출시각) ----
  Future<void> submitReport(StudyReport report) async {
    final now = DateTime.now();
    await _reports.doc(report.id).set({
      'subject': report.subject,
      'studyMinutes': report.studyMinutes,
      'content': report.content,
      'teacherUid': report.teacherUid,
      'status': ReportStatus.submitted.name,
      'submittedAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    }, SetOptions(merge: true));
  }

  // ---- 학생: 내 기록 전체(최신 갱신순) ----
  Stream<List<StudyReport>> watchMyReports() {
    final id = uid;
    if (id == null) return const Stream.empty();
    return _reports.where('studentUid', isEqualTo: id).snapshots().map((s) {
      final list = s.docs.map((d) => StudyReport.fromMap(d.data())).toList();
      list.sort((a, b) =>
          (b.updatedAt ?? DateTime(0)).compareTo(a.updatedAt ?? DateTime(0)));
      return list;
    });
  }

  // ---- 선생님: 나에게 제출된 기록(제출된 것만, 최신 제출순) ----
  Stream<List<StudyReport>> watchTeacherReports() {
    final id = uid;
    if (id == null) return const Stream.empty();
    return _reports.where('teacherUid', isEqualTo: id).snapshots().map((s) {
      final list = s.docs
          .map((d) => StudyReport.fromMap(d.data()))
          .where((r) => r.isSubmitted)
          .toList();
      list.sort((a, b) =>
          (b.submittedAt ?? DateTime(0)).compareTo(a.submittedAt ?? DateTime(0)));
      return list;
    });
  }
}
