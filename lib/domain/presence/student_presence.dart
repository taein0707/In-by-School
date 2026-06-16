// P6 Activity Monitor(웹 전용) — 학생 수업 참여 상태 + 화면 공유 요청.
//
//   presence/{studentUid}        — 학생 본인이 쓰고, 같은 교실 교사가 읽는다.
//   screenShareRequests/{id}     — 교사가 만들고, 학생이 수락/거절(허가 우선 원칙).
//
// 순수 Dart(도메인) — Flutter 의존 없음(VM 테스트 가능). 색상 매핑은 UI 계층에서.

/// 학생 참여 상태.
enum StudentPresence {
  active, // 🟢 현재 OCL 탭 사용 중
  idle, // 🟡 입력 없음 2분 이상
  away, // 🔴 다른 탭/창/최소화 5초 이상
  offline, // ⚪ 브라우저 종료/네트워크 끊김
  screenSharing; // 📺 화면 공유 중

  static StudentPresence fromName(String? s) =>
      values.firstWhere((e) => e.name == s, orElse: () => StudentPresence.offline);

  String get label => switch (this) {
        StudentPresence.active => '참여중',
        StudentPresence.idle => '비활성',
        StudentPresence.away => '화면 이탈',
        StudentPresence.offline => '오프라인',
        StudentPresence.screenSharing => '화면 공유중',
      };

  String get emoji => switch (this) {
        StudentPresence.active => '🟢',
        StudentPresence.idle => '🟡',
        StudentPresence.away => '🔴',
        StudentPresence.offline => '⚪',
        StudentPresence.screenSharing => '📺',
      };

  /// 교사 대시보드 경고 대상(화면 이탈).
  bool get isAway => this == StudentPresence.away;
}

/// presence/{studentUid} 문서.
class Presence {
  final String studentUid;
  final StudentPresence status;
  final DateTime? lastSeen;
  final int awayCount;
  final DateTime? lastAwayAt;

  const Presence({
    required this.studentUid,
    this.status = StudentPresence.offline,
    this.lastSeen,
    this.awayCount = 0,
    this.lastAwayAt,
  });

  Presence copyWith({StudentPresence? status, DateTime? lastSeen, int? awayCount, DateTime? lastAwayAt}) =>
      Presence(
        studentUid: studentUid,
        status: status ?? this.status,
        lastSeen: lastSeen ?? this.lastSeen,
        awayCount: awayCount ?? this.awayCount,
        lastAwayAt: lastAwayAt ?? this.lastAwayAt,
      );

  Map<String, dynamic> toMap() => {
        'studentUid': studentUid,
        'status': status.name,
        'lastSeen': lastSeen?.toIso8601String(),
        'awayCount': awayCount,
        'lastAwayAt': lastAwayAt?.toIso8601String(),
      };

  factory Presence.fromMap(Map<String, dynamic> m) => Presence(
        studentUid: m['studentUid'] as String? ?? '',
        status: StudentPresence.fromName(m['status'] as String?),
        lastSeen: (m['lastSeen'] as String?) != null ? DateTime.tryParse(m['lastSeen'] as String) : null,
        awayCount: (m['awayCount'] as num?)?.toInt() ?? 0,
        lastAwayAt: (m['lastAwayAt'] as String?) != null ? DateTime.tryParse(m['lastAwayAt'] as String) : null,
      );
}

/// 화면 공유 요청 상태.
enum ScreenShareStatus {
  pending,
  accepted,
  rejected;

  static ScreenShareStatus fromName(String? s) =>
      values.firstWhere((e) => e.name == s, orElse: () => ScreenShareStatus.pending);
}

/// screenShareRequests/{id} 문서.
class ScreenShareRequest {
  final String id;
  final String teacherUid;
  final String studentUid;
  final ScreenShareStatus status;
  final DateTime? createdAt;

  const ScreenShareRequest({
    required this.id,
    required this.teacherUid,
    required this.studentUid,
    this.status = ScreenShareStatus.pending,
    this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'teacherUid': teacherUid,
        'studentUid': studentUid,
        'status': status.name,
        'createdAt': createdAt?.toIso8601String(),
      };

  factory ScreenShareRequest.fromMap(Map<String, dynamic> m) => ScreenShareRequest(
        id: m['id'] as String? ?? '',
        teacherUid: m['teacherUid'] as String? ?? '',
        studentUid: m['studentUid'] as String? ?? '',
        status: ScreenShareStatus.fromName(m['status'] as String?),
        createdAt: (m['createdAt'] as String?) != null ? DateTime.tryParse(m['createdAt'] as String) : null,
      );
}
