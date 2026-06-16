import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/battle/battle.dart';
import '../../domain/battle/battle_engine.dart';
import '../../domain/flashcard/flashcard_deck.dart';
import 'flashcard_repository.dart';

/// 단어 경쟁전(battleSessions) — 기존 플래시카드 덱/카드를 재사용해 생성.
/// 신규 컬렉션은 battleSessions(+ players 서브컬렉션)만 추가한다.
class BattleRepository {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  String? get uid => _auth.currentUser?.uid;
  Future<String> ensureUser() async {
    if (_auth.currentUser == null) await _auth.signInAnonymously();
    return _auth.currentUser!.uid;
  }

  CollectionReference<Map<String, dynamic>> get _sessions => _db.collection('battleSessions');
  CollectionReference<Map<String, dynamic>> _players(String battleId) =>
      _sessions.doc(battleId).collection('players');

  // ---- 교사: 기존 덱으로 경쟁전 생성(즉시 생성) ----
  Future<BattleSession> createFromDeck({
    required FlashcardDeck deck,
    required int questionCount,
    required int timeLimitSec,
    required BattleDifficulty difficulty,
    required int choiceRatio,
    required BattleDirection direction,
  }) async {
    final teacherUid = await ensureUser();
    final cards = await FlashcardRepository().fetchCardsForTeacher(deck.id);
    final ref = _sessions.doc();
    final now = DateTime.now();
    final questions = BattleEngine.generateQuestions(
      cards: cards,
      count: questionCount,
      choiceRatio: choiceRatio,
      difficulty: difficulty,
      direction: direction,
      seed: now.millisecondsSinceEpoch & 0x7fffffff,
    );
    final session = BattleSession(
      id: ref.id,
      title: deck.title,
      teacherUid: teacherUid,
      deckId: deck.id,
      joinCode: BattleEngine.generateJoinCode(now.microsecondsSinceEpoch & 0x7fffffff),
      status: BattleStatus.running, // 생성 즉시 참가 가능
      questionCount: questions.length,
      timeLimitSec: timeLimitSec,
      difficulty: difficulty,
      choiceRatio: choiceRatio,
      direction: direction,
      questions: questions,
      createdAt: now,
      startAt: now,
    );
    await ref.set(session.toMap());
    return session;
  }

  // ---- 교사: 종료 ----
  Future<void> endBattle(String battleId) async {
    await _sessions.doc(battleId).set({
      'status': BattleStatus.ended.name,
      'endAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
  }

  // ---- 공통: 단건 구독(문제 포함) ----
  Stream<BattleSession?> watchBattle(String battleId) => _sessions.doc(battleId).snapshots().map(
        (d) => d.exists ? BattleSession.fromMap(d.data()!) : null,
      );

  // ---- 학생: 참가 코드로 세션 조회 ----
  Future<BattleSession?> findByCode(String code) async {
    final q = await _sessions.where('joinCode', isEqualTo: code.trim().toUpperCase()).limit(1).get();
    if (q.docs.isEmpty) return null;
    return BattleSession.fromMap(q.docs.first.data());
  }

  // ---- 학생: 참가(본인 player 문서 생성) ----
  Future<String> joinBattle({required String battleId, required String nickname}) async {
    final id = await ensureUser();
    final player = BattlePlayer(
      uid: id,
      nickname: nickname.trim().isEmpty ? _guestName(id) : nickname.trim(),
      joinedAt: DateTime.now(),
    );
    await _players(battleId).doc(id).set(player.toMap(), SetOptions(merge: true));
    return id;
  }

  static String _guestName(String uid) =>
      'guest_${uid.substring(0, uid.length < 4 ? uid.length : 4)}';

  // ---- 학생: 진행 갱신(매 문제마다 — 교사 라이브 피드 소스) ----
  /// nickname/joinedAt 은 건드리지 않고 점수/연속 등 통계만 병합한다.
  Future<void> submitStats({
    required String battleId,
    required String uid,
    required int score,
    required int streak,
    required int maxStreak,
    required int correctCount,
    required int wrongCount,
    required int durationSeconds,
    required bool finished,
  }) async {
    await _players(battleId).doc(uid).set({
      'uid': uid,
      'score': score,
      'streak': streak,
      'maxStreak': maxStreak,
      'correctCount': correctCount,
      'wrongCount': wrongCount,
      'durationSeconds': durationSeconds,
      'finished': finished,
      if (finished) 'submittedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
  }

  // ---- 공통: 참가자 구독(점수순 정렬은 메모리에서) ----
  Stream<List<BattlePlayer>> watchPlayers(String battleId) =>
      _players(battleId).snapshots().map((s) {
        final list = s.docs.map((d) => BattlePlayer.fromMap(d.data())).toList();
        list.sort((a, b) {
          final byScore = b.score.compareTo(a.score);
          if (byScore != 0) return byScore;
          return a.durationSeconds.compareTo(b.durationSeconds); // 동점 시 빠른 사람
        });
        return list;
      });
}
