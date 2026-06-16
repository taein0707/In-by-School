import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/assignment/assignment.dart' show Difficulty;
import '../../domain/aiquestion/ai_question_set.dart';
import '../ai/gemini_service.dart' show QuestionGenResult;

/// AI 문제 세트(aiQuestionSets) + 문제(aiQuestions) + 결과(aiQuestionResults).
///
/// 숙제/플래시카드와 동일 패턴: 세트 1개 + 문제 N개를 한 배치로 저장, 권한용
/// teacherUid·studentUids 비정규화, where(==/array-contains)만 사용·정렬은 메모리.
class AiQuestionRepository {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  String? get uid => _auth.currentUser?.uid;
  Future<String> ensureUser() async {
    if (_auth.currentUser == null) await _auth.signInAnonymously();
    return _auth.currentUser!.uid;
  }

  CollectionReference<Map<String, dynamic>> get _sets => _db.collection('aiQuestionSets');
  CollectionReference<Map<String, dynamic>> get _questions => _db.collection('aiQuestions');
  CollectionReference<Map<String, dynamic>> get _results => _db.collection('aiQuestionResults');

  // ---- 선생님: 세트 + 문제 생성(배포) ----
  Future<AiQuestionSet> createSet({
    required String teacherName,
    required String title,
    required String topic,
    required Difficulty difficulty,
    required List<AiQuestion> questions,
    required List<String> studentUids,
    String? sourceDeckId,
    required QuestionGenResult gen, // AI 비용/폴백 메타
  }) async {
    final teacherUid = await ensureUser();
    final setRef = _sets.doc();
    final set = AiQuestionSet(
      id: setRef.id,
      teacherUid: teacherUid,
      teacherName: teacherName,
      title: title,
      topic: topic,
      difficulty: difficulty,
      questionCount: questions.length,
      sourceDeckId: sourceDeckId,
      studentUids: studentUids,
      createdAt: DateTime.now(),
      fallbackUsed: gen.fallbackUsed,
      aiModel: gen.model,
      aiPromptTokens: gen.promptTokens,
      aiCandidatesTokens: gen.candidatesTokens,
      aiTotalTokens: gen.totalTokens,
    );

    final batch = _db.batch();
    batch.set(setRef, set.toMap());
    for (var i = 0; i < questions.length; i++) {
      final qRef = _questions.doc();
      final q = AiQuestion(
        id: qRef.id,
        setId: setRef.id,
        type: questions[i].type,
        prompt: questions[i].prompt,
        choices: questions[i].choices,
        answer: questions[i].answer,
        explanation: questions[i].explanation,
        order: i,
      );
      batch.set(qRef, {...q.toMap(), 'teacherUid': teacherUid, 'studentUids': studentUids});
    }
    await batch.commit();
    return set;
  }

  /// 단건 조회(딥링크/알림 이동용).
  Future<AiQuestionSet?> fetchSet(String setId) async {
    final d = await _sets.doc(setId).get();
    return d.exists ? AiQuestionSet.fromMap(d.data()!) : null;
  }

  /// 세트 삭제 — 문제 + 학생 풀이결과(aiQuestionResults)까지 연쇄 삭제.
  Future<void> deleteSet(String setId) async {
    // teacherUid 필터로 read 규칙 충족 — 부모ID(setId) 단독 쿼리는 permission-denied.
    final qDocs = await _questions.where('setId', isEqualTo: setId).where('teacherUid', isEqualTo: uid).get();
    final rDocs = await _results.where('setId', isEqualTo: setId).where('teacherUid', isEqualTo: uid).get();
    final batch = _db.batch();
    for (final d in qDocs.docs) {
      batch.delete(d.reference);
    }
    for (final d in rDocs.docs) {
      batch.delete(d.reference);
    }
    batch.delete(_sets.doc(setId));
    await batch.commit();
  }

  // ---- 선생님: 내 세트(최신순) ----
  Stream<List<AiQuestionSet>> watchSetsByTeacher() {
    final id = uid;
    if (id == null) return const Stream.empty();
    return _sets.where('teacherUid', isEqualTo: id).snapshots().map((s) {
      final list = s.docs.map((d) => AiQuestionSet.fromMap(d.data())).toList();
      list.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      return list;
    });
  }

  // ---- 학생: 나에게 배포된 세트(최신순) ----
  Stream<List<AiQuestionSet>> watchSetsForStudent() {
    final id = uid;
    if (id == null) return const Stream.empty();
    return _sets.where('studentUids', arrayContains: id).snapshots().map((s) {
      final list = s.docs.map((d) => AiQuestionSet.fromMap(d.data())).toList();
      list.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      return list;
    });
  }

  // ---- 한 세트의 문제(순서대로) ----
  // 보안규칙(teacherUid==uid || uid in studentUids)을 쿼리 필터로 충족해야 한다
  // (rules-are-not-filters). 따라서 학생용/교사용을 분리한다.

  /// 학생: 내게 배포된 세트의 문제(풀이용). studentUids array-contains 로 규칙 충족.
  Future<List<AiQuestion>> fetchQuestionsForStudent(String setId) async {
    final id = uid;
    if (id == null) return const [];
    final s = await _questions
        .where('setId', isEqualTo: setId)
        .where('studentUids', arrayContains: id)
        .get();
    final list = s.docs.map((d) => AiQuestion.fromMap(d.data())).toList();
    list.sort((a, b) => a.order.compareTo(b.order));
    return list;
  }

  /// 선생님: 내 세트의 문제(상세 미리보기). teacherUid==uid 로 규칙 충족.
  Stream<List<AiQuestion>> watchQuestionsForTeacher(String setId) {
    final id = uid;
    if (id == null) return const Stream.empty();
    return _questions
        .where('setId', isEqualTo: setId)
        .where('teacherUid', isEqualTo: id)
        .snapshots()
        .map((s) {
      final list = s.docs.map((d) => AiQuestion.fromMap(d.data())).toList();
      list.sort((a, b) => a.order.compareTo(b.order));
      return list;
    });
  }

  // ---- 선생님: 한 세트의 학생별 결과(teacherUid 필터로 규칙 충족) ----
  Stream<List<AiQuestionResult>> watchResultsForSet(String setId) {
    final id = uid;
    if (id == null) return const Stream.empty();
    return _results
        .where('setId', isEqualTo: setId)
        .where('teacherUid', isEqualTo: id)
        .snapshots()
        .map((s) => s.docs.map((d) => AiQuestionResult.fromMap(d.data())).toList());
  }

  // ---- 학생: 내 결과 전체(setId → result) ----
  Stream<List<AiQuestionResult>> watchMyResults() {
    final id = uid;
    if (id == null) return const Stream.empty();
    return _results
        .where('studentUid', isEqualTo: id)
        .snapshots()
        .map((s) => s.docs.map((d) => AiQuestionResult.fromMap(d.data())).toList());
  }

  // ---- 학생: 자동 채점 후 결과 저장 ----
  Future<AiQuestionResult> submitAnswers({
    required AiQuestionSet set,
    required List<AiQuestion> questions,
    required List<String> givens, // questions 와 동일 순서
    required String studentName,
  }) async {
    final studentUid = await ensureUser();
    final id = AiQuestionResult.idFor(set.id, studentUid);
    final responses = <QuestionResponse>[];
    var correct = 0;
    for (var i = 0; i < questions.length; i++) {
      final given = i < givens.length ? givens[i] : '';
      final ok = questions[i].isCorrect(given);
      if (ok) correct++;
      responses.add(QuestionResponse(given: given, correct: ok));
    }
    final now = DateTime.now();
    final result = AiQuestionResult(
      id: id,
      setId: set.id,
      teacherUid: set.teacherUid,
      studentUid: studentUid,
      studentName: studentName,
      total: questions.length,
      correctCount: correct,
      responses: responses,
      completedAt: now,
      updatedAt: now,
    );
    await _results.doc(id).set(result.toMap(), SetOptions(merge: true));
    return result;
  }
}
