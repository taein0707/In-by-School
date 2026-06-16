import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/engagement/bingo_game.dart';

/// 빙고(P4-1) — bingoGames. 턴제 진행은 트랜잭션으로 동시성 보호.
/// teacherUid 비정규화 + read:인증 / create:교사 / update:참가자(teacherUid 불변).
class BingoRepository {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  String? get uid => _auth.currentUser?.uid;
  Future<String> ensureUser() async {
    if (_auth.currentUser == null) await _auth.signInAnonymously();
    return _auth.currentUser!.uid;
  }

  CollectionReference<Map<String, dynamic>> get _games => _db.collection('bingoGames');

  Future<BingoGame> createBingo({
    required String classroomId,
    required String title,
    required int size,
    required BingoMode mode,
    required List<String> words,
  }) async {
    final teacherUid = await ensureUser();
    final ref = _games.doc();
    final game = BingoGame(
      id: ref.id,
      classroomId: classroomId,
      teacherUid: teacherUid,
      title: title,
      size: size,
      mode: mode,
      words: words,
      status: BingoStatus.waiting,
      createdAt: DateTime.now(),
    );
    await ref.set(game.toMap());
    return game;
  }

  Future<void> deleteBingo(String gameId) async {
    await _games.doc(gameId).delete();
  }

  Stream<List<BingoGame>> watchBingosByClassroom(String classroomId) {
    return _games.where('classroomId', isEqualTo: classroomId).snapshots().map((s) {
      final list = s.docs.map((d) => BingoGame.fromMap(d.data())).toList();
      list.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      return list;
    });
  }

  Stream<BingoGame?> watchBingo(String gameId) {
    return _games.doc(gameId).snapshots().map((d) => d.exists ? BingoGame.fromMap(d.data()!) : null);
  }

  /// 참가 — 보드 자동 생성 후 turnOrder 에 합류(이미 참가했으면 무시).
  Future<void> joinBingo({required String gameId, required String displayName}) async {
    final me = await ensureUser();
    final ref = _games.doc(gameId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final game = BingoGame.fromMap(snap.data()!);
      if (game.turnOrder.contains(me)) return;
      final order = [...game.turnOrder, me];
      final boards = {...game.boards, me: BingoLogic.generateBoard(game.words, game.size)};
      final names = {...game.names, me: displayName};
      tx.update(ref, {
        'turnOrder': order,
        'boards': boards.map((k, v) => MapEntry(k, v)),
        'names': names,
      });
    });
  }

  /// 게임 시작(교사) — 첫 차례 지정.
  Future<void> startBingo(String gameId) async {
    final ref = _games.doc(gameId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final game = BingoGame.fromMap(snap.data()!);
      if (game.turnOrder.isEmpty) return;
      tx.update(ref, {
        'status': BingoStatus.playing.name,
        'currentTurn': game.turnOrder.first,
      });
    });
  }

  /// 단어 호출(자기 차례). 보드 완성 시 우승 처리, 아니면 다음 차례로.
  Future<void> callWord({required String gameId, required String word}) async {
    final me = await ensureUser();
    final w = word.trim();
    if (w.isEmpty) return;
    final ref = _games.doc(gameId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final game = BingoGame.fromMap(snap.data()!);
      if (game.status != BingoStatus.playing || game.currentTurn != me) return;
      final called = [...game.calledWords];
      if (!called.contains(w)) called.add(w);
      final completed = <String>[
        for (final u in game.turnOrder)
          if (BingoLogic.isBoardComplete(game.boards[u] ?? const [], called)) u,
      ];
      final myComplete = BingoLogic.isBoardComplete(game.boards[me] ?? const [], called);
      tx.update(ref, {
        'calledWords': called,
        'completedUsers': completed,
        if (myComplete) 'winner': me,
        if (myComplete) 'status': BingoStatus.finished.name,
        if (!myComplete) 'currentTurn': BingoLogic.nextTurn(game.turnOrder, me),
      });
    });
  }
}
