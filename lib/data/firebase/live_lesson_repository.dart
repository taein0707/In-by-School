import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/lesson/live.dart';

/// Teacher Live Mode + 실시간 응답 저장소(P10-2).
/// 세션 doc id = lessonId. 응답은 teacherUid 비정규화로 교사가 get() 없이 전체 조회.
class LiveLessonRepository {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  String? get uid => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _sessions => _db.collection('lessonSessions');
  CollectionReference<Map<String, dynamic>> get _responses => _db.collection('lessonResponses');

  // ---- 교사: 세션 시작/제어 ----
  Future<void> startSession({required String lessonId, required String classroomId}) async {
    final teacherUid = uid;
    if (teacherUid == null) return;
    final session = LessonSession(
      lessonId: lessonId,
      teacherUid: teacherUid,
      classroomId: classroomId,
      currentSlide: 0,
      live: true,
      startedAt: DateTime.now(),
    );
    await _sessions.doc(lessonId).set(session.toMap());
  }

  Future<void> _patch(String lessonId, Map<String, dynamic> patch) =>
      _sessions.doc(lessonId).set(patch, SetOptions(merge: true));

  Future<void> goToSlide(String lessonId, int index) => _patch(lessonId, {'currentSlide': index});
  Future<void> setPaused(String lessonId, bool paused) => _patch(lessonId, {'paused': paused});
  Future<void> setAllowFreeMove(String lessonId, bool v) => _patch(lessonId, {'allowFreeMove': v});
  Future<void> endSession(String lessonId) => _patch(lessonId, {'live': false, 'paused': false});

  Stream<LessonSession?> watchSession(String lessonId) =>
      _sessions.doc(lessonId).snapshots().map((d) => d.exists ? LessonSession.fromMap(d.data()!) : null);

  /// 학생: 내가 속한 교실의 라이브 세션(없으면 null).
  Stream<LessonSession?> watchLiveSessionForClassroom(String classroomId) => _sessions
      .where('classroomId', isEqualTo: classroomId)
      .where('live', isEqualTo: true)
      .limit(1)
      .snapshots()
      .map((s) => s.docs.isEmpty ? null : LessonSession.fromMap(s.docs.first.data()));

  // ---- 학생: 응답 제출 ----
  /// 다중 제출(아이디어보드 등) — 매번 새 문서.
  Future<void> addResponse(LessonResponse r) {
    final ref = _responses.doc();
    return ref.set({...r.toMap(), 'id': ref.id, 'createdAt': DateTime.now().toIso8601String()});
  }

  /// 단일 제출(객관식/투표/텍스트) — 학생당 슬라이드 1개, 덮어쓰기.
  Future<void> upsertResponse(LessonResponse r) {
    final id = '${r.lessonId}_${r.slideId}_${r.studentUid}';
    return _responses.doc(id).set(
          {...r.toMap(), 'id': id, 'createdAt': DateTime.now().toIso8601String()},
          SetOptions(merge: true),
        );
  }

  Future<void> deleteResponse(String id) => _responses.doc(id).delete();

  // ---- 교사: 응답 구독(teacherUid 매칭이라 전체 조회 가능) ----
  Stream<List<LessonResponse>> watchResponses(String lessonId) =>
      _responses.where('lessonId', isEqualTo: lessonId).snapshots().map((s) {
        final list = s.docs.map((d) => LessonResponse.fromMap(d.data())).toList();
        list.sort((a, b) => (a.createdAt ?? DateTime(0)).compareTo(b.createdAt ?? DateTime(0)));
        return list;
      });

  // ---- 학생용 라이브 집계(P10-3) — 교사가 계산해 쓰고, 학생이 읽는다 ----
  // [collection] = 'lessonWordCloud' | 'lessonVotes'. doc id = '{lessonId}_{slideId}'.
  Future<void> writeTally({
    required String collection,
    required String lessonId,
    required String slideId,
    required Map<String, int> counts,
  }) {
    final teacherUid = uid;
    if (teacherUid == null) return Future<void>.value();
    return _db.collection(collection).doc('${lessonId}_$slideId').set({
      'lessonId': lessonId,
      'slideId': slideId,
      'teacherUid': teacherUid,
      'counts': counts,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  Stream<Map<String, int>> watchTally({required String collection, required String lessonId, required String slideId}) =>
      _db.collection(collection).doc('${lessonId}_$slideId').snapshots().map((d) {
        final raw = d.data()?['counts'];
        if (raw is! Map) return const <String, int>{};
        return {for (final e in raw.entries) e.key.toString(): (e.value as num).toInt()};
      });

  // ---- Teacher Pointer(P10-3) — doc id = lessonId ----
  CollectionReference<Map<String, dynamic>> get _pointers => _db.collection('lessonPointers');

  Future<void> setPointer({required String lessonId, required double x, required double y, required String color, required bool active}) {
    final teacherUid = uid;
    if (teacherUid == null) return Future<void>.value();
    return _pointers.doc(lessonId).set(
        LessonPointer(lessonId: lessonId, teacherUid: teacherUid, x: x, y: y, color: color, active: active).toMap());
  }

  Stream<LessonPointer?> watchPointer(String lessonId) =>
      _pointers.doc(lessonId).snapshots().map((d) => d.exists ? LessonPointer.fromMap(d.data()!) : null);

  // ---- 익명 질문(P10-3) ----
  CollectionReference<Map<String, dynamic>> get _questions => _db.collection('lessonQuestions');

  Future<void> addQuestion(LessonQuestion q) {
    final ref = _questions.doc();
    return ref.set({...q.toMap(), 'id': ref.id, 'createdAt': DateTime.now().toIso8601String()});
  }

  Future<void> approveQuestion(String id) => _questions.doc(id).set({'approved': true}, SetOptions(merge: true));
  Future<void> deleteQuestion(String id) => _questions.doc(id).delete();

  Stream<List<LessonQuestion>> watchQuestions(String lessonId) =>
      _questions.where('lessonId', isEqualTo: lessonId).snapshots().map((s) {
        final list = s.docs.map((d) => LessonQuestion.fromMap(d.data())).toList();
        list.sort((a, b) => (a.createdAt ?? DateTime(0)).compareTo(b.createdAt ?? DateTime(0)));
        return list;
      });

  // ---- 아이디어보드 포스트잇(P10-4) — 누구나 보드를 읽고, 교사가 정리 ----
  CollectionReference<Map<String, dynamic>> get _ideas => _db.collection('lessonIdeas');

  Future<void> addIdea(LessonIdea idea) {
    final ref = _ideas.doc();
    return ref.set({...idea.toMap(), 'id': ref.id, 'createdAt': DateTime.now().toIso8601String()});
  }

  Future<void> updateIdea(String id, Map<String, dynamic> patch) => _ideas.doc(id).set(patch, SetOptions(merge: true));
  Future<void> deleteIdea(String id) => _ideas.doc(id).delete();

  Stream<List<LessonIdea>> watchIdeas(String lessonId) =>
      _ideas.where('lessonId', isEqualTo: lessonId).snapshots().map((s) {
        final list = s.docs.map((d) => LessonIdea.fromMap(d.data())).toList();
        list.sort((a, b) => a.zIndex.compareTo(b.zIndex));
        return list;
      });

  // ---- 좋아요 반응(P10-4) — 학생당 (대상,emoji) 토글 ----
  CollectionReference<Map<String, dynamic>> get _reactions => _db.collection('lessonReactions');

  Future<void> toggleReaction({
    required String lessonId,
    required String targetId,
    required String emoji,
    required String studentUid,
  }) async {
    final id = '${lessonId}_${targetId}_${emoji}_$studentUid';
    final doc = _reactions.doc(id);
    final snap = await doc.get();
    if (snap.exists) {
      await doc.delete();
    } else {
      await doc.set(LessonReaction(id: id, lessonId: lessonId, targetId: targetId, emoji: emoji, studentUid: studentUid).toMap());
    }
  }

  Stream<List<LessonReaction>> watchReactions(String lessonId) =>
      _reactions.where('lessonId', isEqualTo: lessonId).snapshots().map((s) => s.docs.map((d) => LessonReaction.fromMap(d.data())).toList());
}
