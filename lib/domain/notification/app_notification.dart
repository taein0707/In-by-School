// 인앱 알림 — 최상위 컬렉션 notifications/{id}, 수신자별 조회(toUid).
// 실제 푸시(FCM)는 Cloud Functions 가 이 문서 생성을 트리거로 보낸다.
// 클라이언트는 이 컬렉션을 Snapshot Listener 로 구독해 알림함을 그린다.

enum NotifKind {
  // 학생 수신
  newAssignment, // 새 숙제
  newFlashcards, // 새 플래시 카드
  newAiQuestions, // 새 AI 문제
  dueSoon, // 마감 임박
  linkRequest, // 선생님 연결 요청
  // 선생님 수신
  submissionDone, // 숙제 완료
  linkAccepted, // 학생 연결 수락
  goalReached; // 학습 목표 달성

  static NotifKind fromName(String? s) =>
      values.firstWhere((e) => e.name == s, orElse: () => NotifKind.newAssignment);
}

class AppNotification {
  final String id;
  final String toUid; // 수신자
  final String fromUid; // 발신자(선생님/학생)
  final NotifKind kind;
  final String title;
  final String body;
  final String? refId; // 연관 문서(assignmentId, deckId, linkId 등)
  final bool read;
  final DateTime? createdAt;

  const AppNotification({
    required this.id,
    required this.toUid,
    this.fromUid = '',
    required this.kind,
    this.title = '',
    this.body = '',
    this.refId,
    this.read = false,
    this.createdAt,
  });

  AppNotification copyWith({bool? read}) => AppNotification(
        id: id,
        toUid: toUid,
        fromUid: fromUid,
        kind: kind,
        title: title,
        body: body,
        refId: refId,
        read: read ?? this.read,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'toUid': toUid,
        'fromUid': fromUid,
        'kind': kind.name,
        'title': title,
        'body': body,
        'refId': refId,
        'read': read,
        'createdAt': createdAt?.toIso8601String(),
      };

  factory AppNotification.fromMap(Map<String, dynamic> m) => AppNotification(
        id: m['id'] as String? ?? '',
        toUid: m['toUid'] as String? ?? '',
        fromUid: m['fromUid'] as String? ?? '',
        kind: NotifKind.fromName(m['kind'] as String?),
        title: m['title'] as String? ?? '',
        body: m['body'] as String? ?? '',
        refId: m['refId'] as String?,
        read: m['read'] as bool? ?? false,
        createdAt: (m['createdAt'] as String?) != null
            ? DateTime.tryParse(m['createdAt'] as String)
            : null,
      );
}
