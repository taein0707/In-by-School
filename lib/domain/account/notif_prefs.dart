// 알림 수신 설정 — users/{uid}/private/settings 에 저장(본인 전용).
// Cloud Functions 가 발송 전 이 설정을 확인해 종류별로 푸시를 거른다.
// 기본값은 모두 켜짐(true).

class NotifPrefs {
  final bool all; // 전체 알림(끄면 모든 푸시 차단)
  final bool assignment; // 숙제
  final bool flashcard; // 플래시카드
  final bool ai; // AI 문제

  const NotifPrefs({
    this.all = true,
    this.assignment = true,
    this.flashcard = true,
    this.ai = true,
  });

  NotifPrefs copyWith({bool? all, bool? assignment, bool? flashcard, bool? ai}) => NotifPrefs(
        all: all ?? this.all,
        assignment: assignment ?? this.assignment,
        flashcard: flashcard ?? this.flashcard,
        ai: ai ?? this.ai,
      );

  Map<String, dynamic> toMap() => {
        'all': all,
        'assignment': assignment,
        'flashcard': flashcard,
        'ai': ai,
      };

  factory NotifPrefs.fromMap(Map<String, dynamic>? m) => NotifPrefs(
        all: m?['all'] as bool? ?? true,
        assignment: m?['assignment'] as bool? ?? true,
        flashcard: m?['flashcard'] as bool? ?? true,
        ai: m?['ai'] as bool? ?? true,
      );
}
