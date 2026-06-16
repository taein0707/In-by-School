import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/engagement/crossword.dart';
import '../../domain/engagement/crossword_set.dart';

/// 가로세로 퍼즐(P4-2) — crosswordSets / crosswordSubmissions.
/// 배치는 로컬 생성 후 저장(전원 동일). teacherUid 비정규화로 규칙 평가.
class CrosswordRepository {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  String? get uid => _auth.currentUser?.uid;
  Future<String> ensureUser() async {
    if (_auth.currentUser == null) await _auth.signInAnonymously();
    return _auth.currentUser!.uid;
  }

  CollectionReference<Map<String, dynamic>> get _sets => _db.collection('crosswordSets');
  CollectionReference<Map<String, dynamic>> get _subs => _db.collection('crosswordSubmissions');

  Future<CrosswordSet> createSet({
    required String classroomId,
    required String title,
    required List<CrosswordWord> words,
  }) async {
    final teacherUid = await ensureUser();
    final ref = _sets.doc();
    final puzzle = CrosswordGenerator.generate(words);
    final set = CrosswordSet(
      id: ref.id,
      classroomId: classroomId,
      teacherUid: teacherUid,
      title: title,
      words: words,
      puzzle: puzzle,
      createdAt: DateTime.now(),
    );
    await ref.set(set.toMap());
    return set;
  }

  Future<void> deleteSet(String setId) async {
    final ss = await _subs.where('setId', isEqualTo: setId).where('teacherUid', isEqualTo: uid).get();
    final batch = _db.batch();
    for (final d in ss.docs) {
      batch.delete(d.reference);
    }
    batch.delete(_sets.doc(setId));
    await batch.commit();
  }

  Stream<List<CrosswordSet>> watchSetsByClassroom(String classroomId) {
    return _sets.where('classroomId', isEqualTo: classroomId).snapshots().map((s) {
      final list = s.docs.map((d) => CrosswordSet.fromMap(d.data())).toList();
      list.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      return list;
    });
  }

  Stream<CrosswordSet?> watchSet(String setId) {
    return _sets.doc(setId).snapshots().map((d) => d.exists ? CrosswordSet.fromMap(d.data()!) : null);
  }

  /// 학생: 진행률 저장(자동 채점 결과 포함).
  Future<void> saveProgress({
    required CrosswordSet set,
    required String studentName,
    required Map<String, String> entries,
    required int correct,
    required int total,
    required bool solved,
  }) async {
    final studentUid = await ensureUser();
    final id = CrosswordSubmission.idFor(set.id, studentUid);
    final sub = CrosswordSubmission(
      id: id,
      setId: set.id,
      teacherUid: set.teacherUid,
      studentUid: studentUid,
      studentName: studentName,
      entries: entries,
      correct: correct,
      total: total,
      solved: solved,
      updatedAt: DateTime.now(),
    );
    await _subs.doc(id).set(sub.toMap(), SetOptions(merge: true));
  }

  /// 학생: 내 제출(이어풀기).
  Stream<CrosswordSubmission?> watchMySubmission(String setId) {
    final id = uid;
    if (id == null) return const Stream.empty();
    return _subs.doc(CrosswordSubmission.idFor(setId, id)).snapshots().map((d) => d.exists ? CrosswordSubmission.fromMap(d.data()!) : null);
  }

  /// 교사: 제출 현황.
  Stream<List<CrosswordSubmission>> watchSubmissions(String setId) {
    final id = uid;
    if (id == null) return const Stream.empty();
    return _subs.where('setId', isEqualTo: setId).where('teacherUid', isEqualTo: id).snapshots().map((s) {
      final list = s.docs.map((d) => CrosswordSubmission.fromMap(d.data())).toList();
      list.sort((a, b) => b.correct.compareTo(a.correct));
      return list;
    });
  }
}
