import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/worksheet/worksheet.dart';
import '../../domain/worksheet/worksheet_question.dart';
import '../../domain/worksheet/worksheet_submission.dart';

/// 온라인 학습지(P3-1) — worksheets/worksheetQuestions/worksheetSubmissions.
/// teacherUid 비정규화로 보안규칙 평가, where(==) 위주 + 메모리 정렬.
class WorksheetRepository {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  String? get uid => _auth.currentUser?.uid;
  Future<String> ensureUser() async {
    if (_auth.currentUser == null) await _auth.signInAnonymously();
    return _auth.currentUser!.uid;
  }

  CollectionReference<Map<String, dynamic>> get _sheets => _db.collection('worksheets');
  CollectionReference<Map<String, dynamic>> get _questions => _db.collection('worksheetQuestions');
  CollectionReference<Map<String, dynamic>> get _subs => _db.collection('worksheetSubmissions');

  // ---- 교사: 학습지 ----
  Future<Worksheet> createWorksheet({
    required String classroomId,
    required String title,
    String description = '',
  }) async {
    final teacherUid = await ensureUser();
    final ref = _sheets.doc();
    final now = DateTime.now();
    final w = Worksheet(
      id: ref.id,
      classroomId: classroomId,
      teacherUid: teacherUid,
      title: title,
      description: description,
      createdAt: now,
      updatedAt: now,
    );
    await ref.set(w.toMap());
    return w;
  }

  Future<void> updateWorksheet(Worksheet w) async {
    await _sheets.doc(w.id).set({
      'title': w.title,
      'description': w.description,
      'teacherUid': w.teacherUid,
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteWorksheet(String worksheetId) async {
    final qs = await _questions.where('worksheetId', isEqualTo: worksheetId).where('teacherUid', isEqualTo: uid).get();
    final ss = await _subs.where('worksheetId', isEqualTo: worksheetId).where('teacherUid', isEqualTo: uid).get();
    final batch = _db.batch();
    for (final d in qs.docs) {
      batch.delete(d.reference);
    }
    for (final d in ss.docs) {
      batch.delete(d.reference);
    }
    batch.delete(_sheets.doc(worksheetId));
    await batch.commit();
  }

  Stream<List<Worksheet>> watchWorksheetsByClassroom(String classroomId) {
    return _sheets.where('classroomId', isEqualTo: classroomId).snapshots().map((s) {
      final list = s.docs.map((d) => Worksheet.fromMap(d.data())).toList();
      list.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      return list;
    });
  }

  // ---- 교사: 문항 ----
  Future<void> createQuestion({
    required String worksheetId,
    required WorksheetQuestionType type,
    required String question,
    List<String> choices = const [],
    String answer = '',
    required int order,
  }) async {
    final teacherUid = await ensureUser();
    final ref = _questions.doc();
    final q = WorksheetQuestion(
      id: ref.id,
      worksheetId: worksheetId,
      teacherUid: teacherUid,
      type: type,
      question: question,
      choices: choices,
      answer: answer,
      order: order,
    );
    await ref.set(q.toMap());
  }

  Future<void> updateQuestion(WorksheetQuestion q) async {
    await _questions.doc(q.id).set(q.toMap(), SetOptions(merge: true));
  }

  Future<void> deleteQuestion(String questionId) async {
    await _questions.doc(questionId).delete();
  }

  Stream<List<WorksheetQuestion>> watchQuestions(String worksheetId) {
    return _questions.where('worksheetId', isEqualTo: worksheetId).snapshots().map((s) {
      final list = s.docs.map((d) => WorksheetQuestion.fromMap(d.data())).toList();
      list.sort((a, b) => a.order.compareTo(b.order));
      return list;
    });
  }

  // ---- 학생: 제출(자동 채점 결과 포함) ----
  Future<void> submitWorksheet({
    required Worksheet worksheet,
    required String studentName,
    required Map<String, String> answers,
    required int score,
    required int total,
  }) async {
    final studentUid = await ensureUser();
    final id = WorksheetSubmission.idFor(worksheet.id, studentUid);
    final sub = WorksheetSubmission(
      id: id,
      worksheetId: worksheet.id,
      teacherUid: worksheet.teacherUid,
      studentUid: studentUid,
      studentName: studentName,
      answers: answers,
      score: score,
      total: total,
      submittedAt: DateTime.now(),
    );
    await _subs.doc(id).set(sub.toMap(), SetOptions(merge: true));
  }

  // ---- 교사: 제출 현황 ----
  Stream<List<WorksheetSubmission>> watchSubmissions(String worksheetId) {
    final id = uid;
    if (id == null) return const Stream.empty();
    return _subs.where('worksheetId', isEqualTo: worksheetId).where('teacherUid', isEqualTo: id).snapshots().map((s) {
      final list = s.docs.map((d) => WorksheetSubmission.fromMap(d.data())).toList();
      list.sort((a, b) => (b.submittedAt ?? DateTime(0)).compareTo(a.submittedAt ?? DateTime(0)));
      return list;
    });
  }

  // ---- 교사: 점수 수동 보정(서술형 채점 등) ----
  Future<void> gradeSubmission({required String submissionId, required int score}) async {
    await _subs.doc(submissionId).set({'score': score}, SetOptions(merge: true));
  }
}
