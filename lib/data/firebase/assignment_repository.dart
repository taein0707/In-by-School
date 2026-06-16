import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/assignment/assignment.dart';

/// 숙제(assignments) + 학생 제출(submissions) 접근.
///
/// 설계(Phase 1 MVP):
///  - 제출 문서는 학생이 '지연 생성'한다(보안규칙상 학생만 자기 제출 write).
///    선생님은 명단(assignment.studentUids)과 존재하는 제출을 조인해 현황 표시.
///  - 복합 인덱스를 피하려 where(==/array-contains)만 쓰고 정렬은 메모리에서.
class AssignmentRepository {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  String? get uid => _auth.currentUser?.uid;
  Future<String> ensureUser() async {
    if (_auth.currentUser == null) await _auth.signInAnonymously();
    return _auth.currentUser!.uid;
  }

  CollectionReference<Map<String, dynamic>> get _assignments => _db.collection('assignments');
  CollectionReference<Map<String, dynamic>> get _submissions => _db.collection('submissions');

  // ---- 선생님: 생성 ----
  Future<Assignment> createAssignment({
    required String teacherName,
    required String title,
    required String description,
    DateTime? dueDate,
    required List<String> studentUids,
    AssignmentType type = AssignmentType.free,
    Difficulty difficulty = Difficulty.medium,
  }) async {
    final teacherUid = await ensureUser();
    final ref = _assignments.doc();
    final assignment = Assignment(
      id: ref.id,
      teacherUid: teacherUid,
      teacherName: teacherName,
      title: title,
      description: description,
      type: type,
      difficulty: difficulty,
      dueDate: dueDate,
      studentUids: studentUids,
      createdAt: DateTime.now(),
    );
    await ref.set(assignment.toMap());
    return assignment;
  }

  /// 숙제 삭제 — 연관 제출(submissions)까지 연쇄 삭제(참조 무결성).
  Future<void> deleteAssignment(String id) async {
    // teacherUid 필터로 read 규칙(teacherUid==uid) 충족 — 부모ID 단독 쿼리는 permission-denied.
    final subs =
        await _submissions.where('assignmentId', isEqualTo: id).where('teacherUid', isEqualTo: uid).get();
    final batch = _db.batch();
    for (final d in subs.docs) {
      batch.delete(d.reference);
    }
    batch.delete(_assignments.doc(id));
    await batch.commit();
  }

  /// 단건 조회(딥링크/알림 이동용).
  Future<Assignment?> fetchAssignment(String id) async {
    final d = await _assignments.doc(id).get();
    return d.exists ? Assignment.fromMap(d.data()!) : null;
  }

  // ---- 선생님: 내 숙제 목록(최신순) ----
  Stream<List<Assignment>> watchAssignmentsByTeacher() {
    final id = uid;
    if (id == null) return const Stream.empty();
    return _assignments.where('teacherUid', isEqualTo: id).snapshots().map((s) {
      final list = s.docs.map((d) => Assignment.fromMap(d.data())).toList();
      list.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      return list;
    });
  }

  // ---- 선생님: 한 숙제의 제출 현황(teacherUid 필터로 규칙 충족) ----
  Stream<List<Submission>> watchSubmissionsForAssignment(String assignmentId) {
    final id = uid;
    if (id == null) return const Stream.empty();
    return _submissions
        .where('assignmentId', isEqualTo: assignmentId)
        .where('teacherUid', isEqualTo: id)
        .snapshots()
        .map((s) => s.docs.map((d) => Submission.fromMap(d.data())).toList());
  }

  // ---- 학생: 나에게 배포된 숙제(최신순) ----
  Stream<List<Assignment>> watchAssignmentsForStudent() {
    final id = uid;
    if (id == null) return const Stream.empty();
    return _assignments.where('studentUids', arrayContains: id).snapshots().map((s) {
      final list = s.docs.map((d) => Assignment.fromMap(d.data())).toList();
      list.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      return list;
    });
  }

  // ---- 학생: 내 제출 전체(목록 화면에서 상태 조인) ----
  Stream<List<Submission>> watchMySubmissions() {
    final id = uid;
    if (id == null) return const Stream.empty();
    return _submissions
        .where('studentUid', isEqualTo: id)
        .snapshots()
        .map((s) => s.docs.map((d) => Submission.fromMap(d.data())).toList());
  }

  // ---- 학생: 완료 토글 / 메모 제출(지연 upsert) ----
  Future<void> upsertMySubmission({
    required Assignment assignment,
    required String studentName,
    SubmissionStatus? status,
    String? memo,
  }) async {
    final studentUid = await ensureUser();
    final id = Submission.idFor(assignment.id, studentUid);
    final now = DateTime.now();
    final data = <String, dynamic>{
      'id': id,
      'assignmentId': assignment.id,
      'teacherUid': assignment.teacherUid,
      'studentUid': studentUid,
      'studentName': studentName,
      'updatedAt': now.toIso8601String(),
    };
    if (status != null) {
      data['status'] = status.name;
      data['completedAt'] = status == SubmissionStatus.done ? now.toIso8601String() : null;
    }
    if (memo != null) data['memo'] = memo;
    await _submissions.doc(id).set(data, SetOptions(merge: true));
  }
}
