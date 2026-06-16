import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/engagement/quiz_competition.dart';
import '../../domain/worksheet/worksheet_question.dart';

/// 수업 퀴즈 대회(P4-3) — quizCompetitions / quizCompetitionPlayers.
/// 문제는 생성 시 학습지 문항을 스냅샷. 실시간 점수/랭킹은 player 문서로 반영.
class QuizRepository {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  String? get uid => _auth.currentUser?.uid;
  Future<String> ensureUser() async {
    if (_auth.currentUser == null) await _auth.signInAnonymously();
    return _auth.currentUser!.uid;
  }

  CollectionReference<Map<String, dynamic>> get _comps => _db.collection('quizCompetitions');
  CollectionReference<Map<String, dynamic>> get _players => _db.collection('quizCompetitionPlayers');

  Future<QuizCompetition> createCompetition({
    required String classroomId,
    required String title,
    required List<WorksheetQuestion> questions,
    required int durationSec,
    required int maxAttempts,
  }) async {
    final teacherUid = await ensureUser();
    final ref = _comps.doc();
    final comp = QuizCompetition(
      id: ref.id,
      classroomId: classroomId,
      teacherUid: teacherUid,
      title: title,
      questions: questions,
      durationSec: durationSec,
      maxAttempts: maxAttempts,
      status: QuizStatus.waiting,
      createdAt: DateTime.now(),
    );
    await ref.set(comp.toMap());
    return comp;
  }

  Future<void> startCompetition(String id) async {
    await _comps.doc(id).set({
      'status': QuizStatus.playing.name,
      'startedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
  }

  Future<void> endCompetition(String id) async {
    await _comps.doc(id).set({'status': QuizStatus.finished.name}, SetOptions(merge: true));
  }

  Future<void> deleteCompetition(String id) async {
    final ps = await _players.where('competitionId', isEqualTo: id).where('teacherUid', isEqualTo: uid).get();
    final batch = _db.batch();
    for (final d in ps.docs) {
      batch.delete(d.reference);
    }
    batch.delete(_comps.doc(id));
    await batch.commit();
  }

  Stream<List<QuizCompetition>> watchCompetitionsByClassroom(String classroomId) {
    return _comps.where('classroomId', isEqualTo: classroomId).snapshots().map((s) {
      final list = s.docs.map((d) => QuizCompetition.fromMap(d.data())).toList();
      list.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      return list;
    });
  }

  Stream<QuizCompetition?> watchCompetition(String id) {
    return _comps.doc(id).snapshots().map((d) => d.exists ? QuizCompetition.fromMap(d.data()!) : null);
  }

  /// 실시간 랭킹(점수순) — 참가자/교사 모두 조회.
  Stream<List<QuizPlayer>> watchPlayers(String competitionId) {
    return _players.where('competitionId', isEqualTo: competitionId).snapshots().map((s) {
      final list = s.docs.map((d) => QuizPlayer.fromMap(d.data())).toList();
      return QuizRanking.sorted(list);
    });
  }

  Stream<QuizPlayer?> watchMyPlayer(String competitionId) {
    final id = uid;
    if (id == null) return const Stream.empty();
    return _players.doc(QuizPlayer.idFor(competitionId, id)).snapshots().map((d) => d.exists ? QuizPlayer.fromMap(d.data()!) : null);
  }

  /// 점수/진행 반영(merge). attempts 는 호출 측에서 증가시켜 전달.
  Future<void> savePlayer({
    required QuizCompetition competition,
    required String studentName,
    required int score,
    required int answered,
    required int attempts,
    required bool finished,
  }) async {
    final studentUid = await ensureUser();
    final id = QuizPlayer.idFor(competition.id, studentUid);
    final player = QuizPlayer(
      id: id,
      competitionId: competition.id,
      teacherUid: competition.teacherUid,
      studentUid: studentUid,
      studentName: studentName,
      score: score,
      answered: answered,
      attempts: attempts,
      finished: finished,
      updatedAt: DateTime.now(),
    );
    await _players.doc(id).set(player.toMap(), SetOptions(merge: true));
  }
}
