// 플래시카드(Phase 2) — 선생님이 직접 입력 또는 OCR로 덱을 만들어 학생에게 배포.
//
// 숙제(assignments/submissions)와 동일한 패턴으로 3개 컬렉션으로 분리:
//   flashcardDecks/{deckId}                  — 덱 메타(제목/설명/과목/대상/카드 수)
//   flashcardCards/{cardId}                  — 카드(앞/뒤/예문/힌트) · deckId 로 묶음
//   flashcardProgress/{deckId}_{studentUid}  — 학생별 학습 결과(시간/정답률/완료율)
//                                              + reviews{cardId: SRS}(Phase B 간격 반복)
//
// 카드를 별도 컬렉션으로 분리한 이유: 덱당 카드 수가 늘어도 덱 목록 쿼리가 가벼워지고
// (cardCount 만 읽음), 카드 단위 확장(개별 진행·즐겨찾기 등)을 열어 둔다.

import 'card_review.dart';

class FlashcardDeck {
  final String id;
  final String teacherUid;
  final String teacherName;
  final String title;
  final String description;
  final String? subject;
  final int cardCount; // 비정규화 — 목록에서 카드 컬렉션을 읽지 않고 표시.
  final bool fromOcr; // OCR로 생성됨(표시/통계용)
  final List<String> studentUids; // 배포 대상
  final DateTime? createdAt;

  const FlashcardDeck({
    required this.id,
    required this.teacherUid,
    this.teacherName = '',
    this.title = '',
    this.description = '',
    this.subject,
    this.cardCount = 0,
    this.fromOcr = false,
    this.studentUids = const [],
    this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'teacherUid': teacherUid,
        'teacherName': teacherName,
        'title': title,
        'description': description,
        'subject': subject,
        'cardCount': cardCount,
        'fromOcr': fromOcr,
        'studentUids': studentUids,
        'createdAt': createdAt?.toIso8601String(),
      };

  factory FlashcardDeck.fromMap(Map<String, dynamic> m) => FlashcardDeck(
        id: m['id'] as String? ?? '',
        teacherUid: m['teacherUid'] as String? ?? '',
        teacherName: m['teacherName'] as String? ?? '',
        title: m['title'] as String? ?? '',
        description: m['description'] as String? ?? '',
        subject: m['subject'] as String?,
        cardCount: (m['cardCount'] as num?)?.toInt() ?? 0,
        fromOcr: m['fromOcr'] as bool? ?? false,
        studentUids: (m['studentUids'] as List?)?.whereType<String>().toList() ?? const [],
        createdAt: (m['createdAt'] as String?) != null
            ? DateTime.tryParse(m['createdAt'] as String)
            : null,
      );
}

/// 카드 1장. flashcardCards/{cardId}. deckId 로 한 덱에 묶이고, 권한용으로
/// teacherUid·studentUids 를 비정규화(보안규칙이 get() 없이 평가되도록).
class Flashcard {
  final String id;
  final String deckId;
  final String front; // 앞면(단어/질문)
  final String back; // 뒷면(뜻/정답)
  final String example; // 예문(선택)
  final String hint; // 힌트(선택)
  final int order; // 정렬 순서

  const Flashcard({
    required this.id,
    required this.deckId,
    this.front = '',
    this.back = '',
    this.example = '',
    this.hint = '',
    this.order = 0,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'deckId': deckId,
        'front': front,
        'back': back,
        'example': example,
        'hint': hint,
        'order': order,
      };

  factory Flashcard.fromMap(Map<String, dynamic> m) => Flashcard(
        id: m['id'] as String? ?? '',
        deckId: m['deckId'] as String? ?? '',
        front: m['front'] as String? ?? '',
        back: m['back'] as String? ?? '',
        example: m['example'] as String? ?? '',
        hint: m['hint'] as String? ?? '',
        order: (m['order'] as num?)?.toInt() ?? 0,
      );
}

/// 카드 학습 시 학생의 자가 평가 — 모름/보통/암기 완료.
enum SelfGrade {
  unknown, // 모름
  normal, // 보통
  known; // 암기 완료

  String get label => switch (this) {
        SelfGrade.unknown => '모름',
        SelfGrade.normal => '보통',
        SelfGrade.known => '암기 완료',
      };

  /// 정답률 가중치 — 모름 0, 보통 0.5, 암기 1.
  double get weight => switch (this) {
        SelfGrade.unknown => 0,
        SelfGrade.normal => 0.5,
        SelfGrade.known => 1,
      };
}

/// 덱 단위 학습 상태(학생 목록 그룹핑용).
enum DeckStudyStatus {
  fresh, // 새 카드(학습 전)
  learning, // 학습 중
  done; // 완료

  String get label => switch (this) {
        DeckStudyStatus.fresh => '새 카드',
        DeckStudyStatus.learning => '학습 중',
        DeckStudyStatus.done => '완료',
      };

  static DeckStudyStatus fromName(String? s) =>
      values.firstWhere((e) => e.name == s, orElse: () => DeckStudyStatus.fresh);
}

/// 학생 1명의 한 덱 학습 결과. flashcardProgress/{deckId}_{studentUid}.
class FlashcardProgress {
  final String id; // '{deckId}_{studentUid}'
  final String deckId;
  final String teacherUid; // 권한/현황용 비정규화
  final String studentUid;
  final String studentName;
  final DeckStudyStatus status;
  final int studiedCards; // 학습한 카드 수
  final int totalCards; // 덱 카드 수(스냅샷)
  final int studySeconds; // 누적 학습 시간(초)
  final double correctRate; // 0~1, 자가 평가 가중 평균
  final DateTime? completedAt;
  final DateTime? updatedAt;
  final Map<String, CardReview> reviews; // cardId → 간격 반복(SRS) 상태 (Phase B)

  const FlashcardProgress({
    required this.id,
    required this.deckId,
    required this.teacherUid,
    required this.studentUid,
    this.studentName = '',
    this.status = DeckStudyStatus.fresh,
    this.studiedCards = 0,
    this.totalCards = 0,
    this.studySeconds = 0,
    this.correctRate = 0,
    this.completedAt,
    this.updatedAt,
    this.reviews = const {},
  });

  static String idFor(String deckId, String studentUid) => '${deckId}_$studentUid';

  bool get isDone => status == DeckStudyStatus.done;

  /// 완료율 0~1 — 학습 카드 / 전체 카드.
  double get completionRate => totalCards == 0 ? 0 : (studiedCards / totalCards).clamp(0, 1);

  int get correctPercent => (correctRate * 100).round();
  int get completionPercent => (completionRate * 100).round();
  int get studyMinutes => studySeconds < 60 ? (studySeconds == 0 ? 0 : 1) : studySeconds ~/ 60;

  Map<String, dynamic> toMap() => {
        'id': id,
        'deckId': deckId,
        'teacherUid': teacherUid,
        'studentUid': studentUid,
        'studentName': studentName,
        'status': status.name,
        'studiedCards': studiedCards,
        'totalCards': totalCards,
        'studySeconds': studySeconds,
        'correctRate': correctRate,
        'completedAt': completedAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
        'reviews': {for (final e in reviews.entries) e.key: e.value.toMap()},
      };

  factory FlashcardProgress.fromMap(Map<String, dynamic> m) => FlashcardProgress(
        id: m['id'] as String? ?? '',
        deckId: m['deckId'] as String? ?? '',
        teacherUid: m['teacherUid'] as String? ?? '',
        studentUid: m['studentUid'] as String? ?? '',
        studentName: m['studentName'] as String? ?? '',
        status: DeckStudyStatus.fromName(m['status'] as String?),
        studiedCards: (m['studiedCards'] as num?)?.toInt() ?? 0,
        totalCards: (m['totalCards'] as num?)?.toInt() ?? 0,
        studySeconds: (m['studySeconds'] as num?)?.toInt() ?? 0,
        correctRate: (m['correctRate'] as num?)?.toDouble() ?? 0,
        completedAt: (m['completedAt'] as String?) != null
            ? DateTime.tryParse(m['completedAt'] as String)
            : null,
        updatedAt: (m['updatedAt'] as String?) != null
            ? DateTime.tryParse(m['updatedAt'] as String)
            : null,
        reviews: (m['reviews'] as Map?)?.map((k, v) =>
                MapEntry(k as String, CardReview.fromMap((v as Map).cast<String, dynamic>()))) ??
            const {},
      );
}
