import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/firebase/flashcard_repository.dart';
import '../domain/flashcard/card_review.dart';
import '../domain/flashcard/flashcard_deck.dart';
import 'account_providers.dart';

final flashcardRepositoryProvider = Provider<FlashcardRepository>((ref) => FlashcardRepository());

/// 미인증(로그아웃/전환)이면 빈 스트림 — stale 리스너 permission-denied 방지(P2-1).
bool _signedOut(Ref ref) =>
    Firebase.apps.isEmpty || ref.watch(authStateProvider).value == null;

/// 선생님: 내가 만든 덱(최신순).
final teacherDecksProvider = StreamProvider<List<FlashcardDeck>>((ref) {
  if (_signedOut(ref)) return Stream.value(const []);
  return ref.watch(flashcardRepositoryProvider).watchDecksByTeacher();
});

/// 학생: 나에게 배포된 덱(최신순).
final studentDecksProvider = StreamProvider<List<FlashcardDeck>>((ref) {
  if (_signedOut(ref)) return Stream.value(const []);
  return ref.watch(flashcardRepositoryProvider).watchDecksForStudent();
});

/// 학생: 내 학습 진행 전체(deckId → progress).
final myFlashcardProgressProvider = StreamProvider<Map<String, FlashcardProgress>>((ref) {
  if (_signedOut(ref)) return Stream.value(const {});
  return ref.watch(flashcardRepositoryProvider).watchMyProgress().map(
        (list) => {for (final p in list) p.deckId: p},
      );
});

/// 선생님: 한 덱의 학생별 학습 현황(studentUid → progress).
final progressForDeckProvider =
    StreamProvider.family<Map<String, FlashcardProgress>, String>((ref, deckId) {
  if (_signedOut(ref)) return Stream.value(const {});
  return ref.watch(flashcardRepositoryProvider).watchProgressForDeck(deckId).map(
        (list) => {for (final p in list) p.studentUid: p},
      );
});

/// 선생님: 내 덱의 카드 목록(상세 미리보기). teacherUid 필터로 규칙 충족.
final cardsForDeckProvider =
    StreamProvider.family<List<Flashcard>, String>((ref, deckId) {
  if (_signedOut(ref)) return Stream.value(const []);
  return ref.watch(flashcardRepositoryProvider).watchCardsForTeacher(deckId);
});

/// 오늘 복습할 카드 1건 — 어느 덱의 어느 카드인지.
class DueCard {
  final String deckId;
  final String cardId;
  const DueCard(this.deckId, this.cardId);
}

/// 학생: 오늘 복습 대상 카드 목록(Phase B 핵심).
/// 기존 진행 스트림(myFlashcardProgress)의 reviews 맵에서 nextReviewAt<=오늘 인
/// 카드를 모은다 — 별도 쿼리/인덱스 없이 파생된다.
final dueReviewsProvider = Provider<List<DueCard>>((ref) {
  // valueOrNull: AsyncError 에서도 rethrow 하지 않고 null 반환(.value 는 rethrow → 홈 크래시).
  final byDeck = ref.watch(myFlashcardProgressProvider).valueOrNull ?? const {};
  final now = DateTime.now();
  final due = <DueCard>[];
  for (final p in byDeck.values) {
    for (final r in p.reviews.values) {
      if (Srs.isDue(r, now)) due.add(DueCard(p.deckId, r.cardId));
    }
  }
  return due;
});

/// 오늘 복습할 카드 수(홈 '오늘 복습' 섹션 표시용).
final dueReviewCountProvider = Provider<int>((ref) => ref.watch(dueReviewsProvider).length);
