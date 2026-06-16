import 'package:flutter_test/flutter_test.dart';
import 'package:ocl_study/domain/flashcard/card_review.dart';
import 'package:ocl_study/domain/flashcard/flashcard_deck.dart' show SelfGrade;

void main() {
  final now = DateTime(2026, 6, 13);

  group('Srs.schedule — SM-2 lite', () {
    test('암기완료 반복 시 간격이 점점 벌어진다', () {
      final r1 = Srs.schedule(CardReview.fresh('a'), SelfGrade.known, now);
      expect(r1.repetition, 1);
      expect(r1.intervalDays, 1);
      expect(r1.ease, greaterThan(2.5));
      expect(r1.nextReviewAt, DateTime(2026, 6, 14));

      final r2 = Srs.schedule(r1, SelfGrade.known, now);
      expect(r2.repetition, 2);
      expect(r2.intervalDays, 3);

      final r3 = Srs.schedule(r2, SelfGrade.known, now);
      expect(r3.repetition, 3);
      expect(r3.intervalDays, greaterThan(3)); // interval * ease
    });

    test('보통도 통과(q>=3) — 반복 증가', () {
      final n1 = Srs.schedule(CardReview.fresh('a'), SelfGrade.normal, now);
      expect(n1.repetition, 1);
      expect(n1.intervalDays, 1);
    });

    test('모름이면 반복 0·간격 1로 리셋, ease 감소', () {
      final r3 = Srs.schedule(
        Srs.schedule(Srs.schedule(CardReview.fresh('a'), SelfGrade.known, now), SelfGrade.known, now),
        SelfGrade.known,
        now,
      );
      final hard = Srs.schedule(r3, SelfGrade.unknown, now);
      expect(hard.repetition, 0);
      expect(hard.intervalDays, 1);
      expect(hard.ease, lessThan(r3.ease));
      expect(hard.ease, greaterThanOrEqualTo(Srs.minEase));
      expect(hard.nextReviewAt, DateTime(2026, 6, 14));
    });

    test('ease 는 하한 1.3 아래로 내려가지 않는다', () {
      var r = CardReview.fresh('a');
      for (var i = 0; i < 10; i++) {
        r = Srs.schedule(r, SelfGrade.unknown, now);
      }
      expect(r.ease, greaterThanOrEqualTo(Srs.minEase));
    });
  });

  group('Srs.isDue — 오늘 복습 대상', () {
    test('아직 복습 안 한 새 카드는 대상 아님', () {
      expect(Srs.isDue(CardReview.fresh('a'), now), isFalse);
    });
    test('예정일이 오늘이면 대상', () {
      expect(Srs.isDue(const CardReview(cardId: 'a').copyWithNext(DateTime(2026, 6, 13)), now), isTrue);
    });
    test('예정일이 지났으면(연체) 대상', () {
      expect(Srs.isDue(const CardReview(cardId: 'a').copyWithNext(DateTime(2026, 6, 10)), now), isTrue);
    });
    test('예정일이 미래면 대상 아님', () {
      expect(Srs.isDue(const CardReview(cardId: 'a').copyWithNext(DateTime(2026, 6, 20)), now), isFalse);
    });
  });
}

/// 테스트 편의 — nextReviewAt 만 지정한 사본.
extension on CardReview {
  CardReview copyWithNext(DateTime next) => CardReview(
        cardId: cardId,
        repetition: repetition,
        intervalDays: intervalDays,
        ease: ease,
        lastReviewedAt: lastReviewedAt,
        nextReviewAt: next,
      );
}
