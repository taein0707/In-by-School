import 'dart:math' as math;

import 'flashcard_deck.dart' show SelfGrade;

/// 카드 1장의 간격 반복(SRS) 상태. flashcardProgress 문서의 `reviews` 맵에
/// cardId 를 키로 임베드된다(별도 컬렉션·인덱스 없이 기존 구조 최소 변경).
class CardReview {
  final String cardId;
  final int repetition; // 연속 통과 횟수(틀리면 0으로 리셋)
  final int intervalDays; // 다음 복습까지 간격(일)
  final double ease; // 난이도 계수(>= 1.3) — 클수록 간격이 빨리 벌어짐
  final DateTime? lastReviewedAt;
  final DateTime? nextReviewAt;

  const CardReview({
    required this.cardId,
    this.repetition = 0,
    this.intervalDays = 0,
    this.ease = 2.5,
    this.lastReviewedAt,
    this.nextReviewAt,
  });

  /// 아직 한 번도 복습하지 않은 새 카드(스케줄 미등록).
  factory CardReview.fresh(String cardId) => CardReview(cardId: cardId);

  Map<String, dynamic> toMap() => {
        'cardId': cardId,
        'repetition': repetition,
        'intervalDays': intervalDays,
        'ease': ease,
        'lastReviewedAt': lastReviewedAt?.toIso8601String(),
        'nextReviewAt': nextReviewAt?.toIso8601String(),
      };

  factory CardReview.fromMap(Map<String, dynamic> m) => CardReview(
        cardId: m['cardId'] as String? ?? '',
        repetition: (m['repetition'] as num?)?.toInt() ?? 0,
        intervalDays: (m['intervalDays'] as num?)?.toInt() ?? 0,
        ease: (m['ease'] as num?)?.toDouble() ?? 2.5,
        lastReviewedAt: (m['lastReviewedAt'] as String?) != null
            ? DateTime.tryParse(m['lastReviewedAt'] as String)
            : null,
        nextReviewAt: (m['nextReviewAt'] as String?) != null
            ? DateTime.tryParse(m['nextReviewAt'] as String)
            : null,
      );
}

/// 간격 반복 스케줄러 — SM-2 의 경량 변형.
/// 자가 평가(SelfGrade)를 품질 점수로 매핑해 다음 복습 간격을 계산한다.
class Srs {
  Srs._();

  static const double minEase = 1.3;

  /// SelfGrade → SM-2 품질 점수(0~5). 모름=실패(<3), 보통=통과, 암기완료=우수.
  static int qualityOf(SelfGrade g) => switch (g) {
        SelfGrade.unknown => 1,
        SelfGrade.normal => 3,
        SelfGrade.known => 5,
      };

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// 한 번의 복습 결과를 반영해 다음 상태를 계산한다(순수 함수).
  static CardReview schedule(CardReview prev, SelfGrade grade, DateTime now) {
    final q = qualityOf(grade);

    // ease 갱신(SM-2): 잘 맞힐수록 증가, 틀리면 감소. 하한 1.3.
    var ease = prev.ease + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02));
    if (ease < minEase) ease = minEase;

    int repetition;
    int interval;
    if (q < 3) {
      // 실패 — 처음부터 다시(내일 복습).
      repetition = 0;
      interval = 1;
    } else {
      repetition = prev.repetition + 1;
      if (repetition <= 1) {
        interval = 1;
      } else if (repetition == 2) {
        interval = 3;
      } else {
        final base = prev.intervalDays <= 0 ? 1 : prev.intervalDays;
        interval = (base * ease).round().clamp(1, 3650);
      }
    }

    final today = _dateOnly(now);
    return CardReview(
      cardId: prev.cardId,
      repetition: repetition,
      intervalDays: interval,
      ease: double.parse(ease.toStringAsFixed(3)),
      lastReviewedAt: now,
      nextReviewAt: today.add(Duration(days: interval)),
    );
  }

  /// 오늘(now) 기준 복습 대상인가 — 스케줄이 잡혀 있고 예정일이 오늘 이하.
  /// 아직 복습한 적 없는 새 카드(nextReviewAt == null)는 '복습' 대상이 아니다.
  static bool isDue(CardReview r, DateTime now) {
    final next = r.nextReviewAt;
    if (next == null) return false;
    return !_dateOnly(next).isAfter(_dateOnly(now));
  }

  /// 표시용 — 다음 복습까지 남은 일수(음수면 0).
  static int daysUntil(CardReview r, DateTime now) {
    final next = r.nextReviewAt;
    if (next == null) return 0;
    return math.max(0, _dateOnly(next).difference(_dateOnly(now)).inDays);
  }
}
