import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/flashcard/card_review.dart';
import '../../domain/flashcard/flashcard_deck.dart';

/// 플래시카드 덱(flashcardDecks) + 카드(flashcardCards) + 학습 결과(flashcardProgress).
///
/// 설계(Phase 2): 숙제(assignments/submissions)와 동일 패턴.
///  - 덱 생성 시 덱 1개 + 카드 N개를 한 배치(batch)로 원자적 저장.
///  - 카드/진행 문서에 teacherUid·studentUids 를 비정규화해 보안규칙이 get() 없이 평가.
///  - 복합 인덱스를 피하려 where(==/array-contains)만 쓰고 정렬은 메모리에서.
class FlashcardRepository {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  String? get uid => _auth.currentUser?.uid;
  Future<String> ensureUser() async {
    if (_auth.currentUser == null) await _auth.signInAnonymously();
    return _auth.currentUser!.uid;
  }

  CollectionReference<Map<String, dynamic>> get _decks => _db.collection('flashcardDecks');
  CollectionReference<Map<String, dynamic>> get _cards => _db.collection('flashcardCards');
  CollectionReference<Map<String, dynamic>> get _progress => _db.collection('flashcardProgress');

  // ---- 선생님: 덱 + 카드 생성(배포) ----
  Future<FlashcardDeck> createDeck({
    required String teacherName,
    required String title,
    required String description,
    String? subject,
    required List<Flashcard> cards, // id/deckId 는 여기서 채운다
    required List<String> studentUids,
    bool fromOcr = false,
  }) async {
    final teacherUid = await ensureUser();
    final deckRef = _decks.doc();
    final deck = FlashcardDeck(
      id: deckRef.id,
      teacherUid: teacherUid,
      teacherName: teacherName,
      title: title,
      description: description,
      subject: subject,
      cardCount: cards.length,
      fromOcr: fromOcr,
      studentUids: studentUids,
      createdAt: DateTime.now(),
    );

    final batch = _db.batch();
    batch.set(deckRef, deck.toMap());
    for (var i = 0; i < cards.length; i++) {
      final cardRef = _cards.doc();
      final card = Flashcard(
        id: cardRef.id,
        deckId: deckRef.id,
        front: cards[i].front,
        back: cards[i].back,
        example: cards[i].example,
        hint: cards[i].hint,
        order: i,
      );
      // teacherUid·studentUids 비정규화(보안규칙용).
      batch.set(cardRef, {
        ...card.toMap(),
        'teacherUid': teacherUid,
        'studentUids': studentUids,
      });
    }
    await batch.commit();
    return deck;
  }

  /// 단건 조회(딥링크/알림 이동용).
  Future<FlashcardDeck?> fetchDeck(String deckId) async {
    final d = await _decks.doc(deckId).get();
    return d.exists ? FlashcardDeck.fromMap(d.data()!) : null;
  }

  /// 덱 삭제 — 카드 + 학생 학습기록(flashcardProgress)까지 연쇄 삭제.
  Future<void> deleteDeck(String deckId) async {
    final cardDocs = await _cards.where('deckId', isEqualTo: deckId).get();
    final progDocs = await _progress.where('deckId', isEqualTo: deckId).get();
    final batch = _db.batch();
    for (final d in cardDocs.docs) {
      batch.delete(d.reference);
    }
    for (final d in progDocs.docs) {
      batch.delete(d.reference);
    }
    batch.delete(_decks.doc(deckId));
    await batch.commit();
  }

  // ---- 선생님: 내 덱 목록(최신순) ----
  Stream<List<FlashcardDeck>> watchDecksByTeacher() {
    final id = uid;
    if (id == null) return const Stream.empty();
    return _decks.where('teacherUid', isEqualTo: id).snapshots().map((s) {
      final list = s.docs.map((d) => FlashcardDeck.fromMap(d.data())).toList();
      list.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      return list;
    });
  }

  // ---- 학생: 나에게 배포된 덱(최신순) ----
  Stream<List<FlashcardDeck>> watchDecksForStudent() {
    final id = uid;
    if (id == null) return const Stream.empty();
    return _decks.where('studentUids', arrayContains: id).snapshots().map((s) {
      final list = s.docs.map((d) => FlashcardDeck.fromMap(d.data())).toList();
      list.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      return list;
    });
  }

  // ---- 한 덱의 카드(순서대로) ----
  // Firestore 보안규칙은 쿼리 필터로 read 분기를 '증명'할 수 있어야 한다(rules-are-not-filters).
  // flashcardCards read = (teacherUid==uid || uid in studentUids) 이므로, 역할에 맞는
  // 필터를 함께 걸어야 거부되지 않는다. deckId 단독 쿼리는 permission-denied.
  List<Flashcard> _sortCards(Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final list = docs.map((d) => Flashcard.fromMap(d.data())).toList();
    list.sort((a, b) => a.order.compareTo(b.order));
    return list;
  }

  /// 학생: 나에게 배포된 덱의 카드(studentUids array-contains 로 규칙 충족).
  Stream<List<Flashcard>> watchCardsForStudent(String deckId) {
    final id = uid;
    if (id == null) return const Stream.empty();
    return _cards
        .where('deckId', isEqualTo: deckId)
        .where('studentUids', arrayContains: id)
        .snapshots()
        .map((s) => _sortCards(s.docs));
  }

  Future<List<Flashcard>> fetchCardsForStudent(String deckId) async {
    final id = uid;
    if (id == null) return const [];
    final s = await _cards.where('deckId', isEqualTo: deckId).where('studentUids', arrayContains: id).get();
    return _sortCards(s.docs);
  }

  /// 선생님: 내 덱의 카드(teacherUid==uid 로 규칙 충족). 상세 미리보기·경쟁전 생성용.
  Stream<List<Flashcard>> watchCardsForTeacher(String deckId) {
    final id = uid;
    if (id == null) return const Stream.empty();
    return _cards
        .where('deckId', isEqualTo: deckId)
        .where('teacherUid', isEqualTo: id)
        .snapshots()
        .map((s) => _sortCards(s.docs));
  }

  Future<List<Flashcard>> fetchCardsForTeacher(String deckId) async {
    final id = uid;
    if (id == null) return const [];
    final s = await _cards.where('deckId', isEqualTo: deckId).where('teacherUid', isEqualTo: id).get();
    return _sortCards(s.docs);
  }

  // ---- 선생님: 한 덱의 학생별 학습 현황(teacherUid==uid 로 규칙 충족) ----
  Stream<List<FlashcardProgress>> watchProgressForDeck(String deckId) {
    final id = uid;
    if (id == null) return const Stream.empty();
    return _progress
        .where('deckId', isEqualTo: deckId)
        .where('teacherUid', isEqualTo: id)
        .snapshots()
        .map((s) => s.docs.map((d) => FlashcardProgress.fromMap(d.data())).toList());
  }

  // ---- 학생: 내 학습 진행 전체(목록에서 상태 조인) ----
  Stream<List<FlashcardProgress>> watchMyProgress() {
    final id = uid;
    if (id == null) return const Stream.empty();
    return _progress
        .where('studentUid', isEqualTo: id)
        .snapshots()
        .map((s) => s.docs.map((d) => FlashcardProgress.fromMap(d.data())).toList());
  }

  // ---- 학생: 학습 결과 저장(upsert) ----
  Future<void> saveProgress({
    required FlashcardDeck deck,
    required String studentName,
    required int studiedCards,
    required int totalCards,
    required int studySeconds,
    required double correctRate,
    required bool completed,
  }) async {
    final studentUid = await ensureUser();
    final id = FlashcardProgress.idFor(deck.id, studentUid);
    final now = DateTime.now();
    final progress = FlashcardProgress(
      id: id,
      deckId: deck.id,
      teacherUid: deck.teacherUid,
      studentUid: studentUid,
      studentName: studentName,
      status: completed ? DeckStudyStatus.done : DeckStudyStatus.learning,
      studiedCards: studiedCards,
      totalCards: totalCards,
      studySeconds: studySeconds,
      correctRate: correctRate,
      completedAt: completed ? now : null,
      updatedAt: now,
    );
    await _progress.doc(id).set(progress.toMap(), SetOptions(merge: true));
  }

  // ---- 학생: 카드 단위 간격 반복(SRS) 상태 저장(Phase B) ----
  /// 복습/학습에서 갱신된 카드별 CardReview 를 flashcardProgress 문서의 reviews 맵에
  /// 병합 저장한다. merge:true 가 nested map 을 깊은 병합하므로, 건드린 cardId 만
  /// 갱신되고 나머지 카드 상태는 보존된다(별도 컬렉션/인덱스 없음).
  Future<void> saveCardReviews({
    required FlashcardDeck deck,
    required Map<String, CardReview> reviews,
  }) async {
    if (reviews.isEmpty) return;
    final studentUid = await ensureUser();
    final id = FlashcardProgress.idFor(deck.id, studentUid);
    await _progress.doc(id).set({
      'id': id,
      'deckId': deck.id,
      'teacherUid': deck.teacherUid,
      'studentUid': studentUid,
      'updatedAt': DateTime.now().toIso8601String(),
      'reviews': {for (final e in reviews.entries) e.key: e.value.toMap()},
    }, SetOptions(merge: true));
  }
}
