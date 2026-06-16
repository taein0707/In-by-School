// Teacher Live Mode + 실시간 참여(P10-2).
//
//   lessonSessions/{lessonId}  — 라이브 세션 상태(교사가 제어, 학생이 구독)
//   lessonResponses/{id}       — 학생 응답(아이디어/텍스트/선택/투표 등)
//
// teacherUid 비정규화로 보안규칙이 get() 없이 평가한다.

/// 라이브 세션 — 교사가 슬라이드를 넘기면 학생이 동시에 이동한다.
class LessonSession {
  final String lessonId;
  final String teacherUid;
  final String classroomId;
  final int currentSlide;
  final bool live;
  final bool paused;
  final bool allowFreeMove;
  final DateTime? startedAt;

  const LessonSession({
    required this.lessonId,
    required this.teacherUid,
    this.classroomId = '',
    this.currentSlide = 0,
    this.live = false,
    this.paused = false,
    this.allowFreeMove = false,
    this.startedAt,
  });

  LessonSession copyWith({int? currentSlide, bool? live, bool? paused, bool? allowFreeMove}) => LessonSession(
        lessonId: lessonId,
        teacherUid: teacherUid,
        classroomId: classroomId,
        currentSlide: currentSlide ?? this.currentSlide,
        live: live ?? this.live,
        paused: paused ?? this.paused,
        allowFreeMove: allowFreeMove ?? this.allowFreeMove,
        startedAt: startedAt,
      );

  Map<String, dynamic> toMap() => {
        'lessonId': lessonId,
        'teacherUid': teacherUid,
        'classroomId': classroomId,
        'currentSlide': currentSlide,
        'live': live,
        'paused': paused,
        'allowFreeMove': allowFreeMove,
        'startedAt': startedAt?.toIso8601String(),
      };

  factory LessonSession.fromMap(Map<String, dynamic> m) => LessonSession(
        lessonId: m['lessonId'] as String? ?? '',
        teacherUid: m['teacherUid'] as String? ?? '',
        classroomId: m['classroomId'] as String? ?? '',
        currentSlide: (m['currentSlide'] as num?)?.toInt() ?? 0,
        live: m['live'] as bool? ?? false,
        paused: m['paused'] as bool? ?? false,
        allowFreeMove: m['allowFreeMove'] as bool? ?? false,
        startedAt: (m['startedAt'] as String?) != null ? DateTime.tryParse(m['startedAt'] as String) : null,
      );
}

/// 응답 종류 — 한 컬렉션(lessonResponses)에서 슬라이드 유형별로 구분.
enum ResponseKind {
  idea, // 아이디어보드 포스트잇
  text, // 짧은/긴 답변, 키워드, exit ticket
  choice, // 객관식/OX
  vote; // 실시간 투표

  static ResponseKind fromName(String? s) =>
      values.firstWhere((e) => e.name == s, orElse: () => ResponseKind.text);
}

/// 학생 응답 한 건.
class LessonResponse {
  final String id;
  final String lessonId;
  final String slideId;
  final String studentUid;
  final String teacherUid; // 비정규화(규칙)
  final String studentName;
  final ResponseKind kind;
  final String text; // 답변/포스트잇/선택지/투표 항목
  final String color; // 포스트잇 색(선택)
  final DateTime? createdAt;

  const LessonResponse({
    required this.id,
    required this.lessonId,
    required this.slideId,
    required this.studentUid,
    required this.teacherUid,
    this.studentName = '',
    this.kind = ResponseKind.text,
    this.text = '',
    this.color = '',
    this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'lessonId': lessonId,
        'slideId': slideId,
        'studentUid': studentUid,
        'teacherUid': teacherUid,
        'studentName': studentName,
        'kind': kind.name,
        'text': text,
        'color': color,
        'createdAt': createdAt?.toIso8601String(),
      };

  factory LessonResponse.fromMap(Map<String, dynamic> m) => LessonResponse(
        id: m['id'] as String? ?? '',
        lessonId: m['lessonId'] as String? ?? '',
        slideId: m['slideId'] as String? ?? '',
        studentUid: m['studentUid'] as String? ?? '',
        teacherUid: m['teacherUid'] as String? ?? '',
        studentName: m['studentName'] as String? ?? '',
        kind: ResponseKind.fromName(m['kind'] as String?),
        text: m['text'] as String? ?? '',
        color: m['color'] as String? ?? '',
        createdAt: (m['createdAt'] as String?) != null ? DateTime.tryParse(m['createdAt'] as String) : null,
      );
}

/// 교사 포인터(P10-3) — 좌표는 슬라이드 영역 기준 0..1 정규화(화면 크기 무관).
class LessonPointer {
  final String lessonId;
  final String teacherUid;
  final double x;
  final double y;
  final String color; // 'yellow'|'red'|'blue'|'laser'
  final bool active;

  const LessonPointer({
    required this.lessonId,
    required this.teacherUid,
    this.x = 0.5,
    this.y = 0.5,
    this.color = 'yellow',
    this.active = false,
  });

  Map<String, dynamic> toMap() => {
        'lessonId': lessonId,
        'teacherUid': teacherUid,
        'x': x,
        'y': y,
        'color': color,
        'active': active,
      };

  factory LessonPointer.fromMap(Map<String, dynamic> m) => LessonPointer(
        lessonId: m['lessonId'] as String? ?? '',
        teacherUid: m['teacherUid'] as String? ?? '',
        x: (m['x'] as num?)?.toDouble() ?? 0.5,
        y: (m['y'] as num?)?.toDouble() ?? 0.5,
        color: m['color'] as String? ?? 'yellow',
        active: m['active'] as bool? ?? false,
      );
}

/// 익명 질문(P10-3) — 학생이 질문 → 교사 승인 후 전체 공개.
class LessonQuestion {
  final String id;
  final String lessonId;
  final String teacherUid;
  final String studentUid;
  final String studentName;
  final String text;
  final bool approved;
  final bool anonymous;
  final DateTime? createdAt;

  const LessonQuestion({
    required this.id,
    required this.lessonId,
    required this.teacherUid,
    required this.studentUid,
    this.studentName = '',
    this.text = '',
    this.approved = false,
    this.anonymous = true,
    this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'lessonId': lessonId,
        'teacherUid': teacherUid,
        'studentUid': studentUid,
        'studentName': studentName,
        'text': text,
        'approved': approved,
        'anonymous': anonymous,
        'createdAt': createdAt?.toIso8601String(),
      };

  factory LessonQuestion.fromMap(Map<String, dynamic> m) => LessonQuestion(
        id: m['id'] as String? ?? '',
        lessonId: m['lessonId'] as String? ?? '',
        teacherUid: m['teacherUid'] as String? ?? '',
        studentUid: m['studentUid'] as String? ?? '',
        studentName: m['studentName'] as String? ?? '',
        text: m['text'] as String? ?? '',
        approved: m['approved'] as bool? ?? false,
        anonymous: m['anonymous'] as bool? ?? true,
        createdAt: (m['createdAt'] as String?) != null ? DateTime.tryParse(m['createdAt'] as String) : null,
      );
}

/// 아이디어보드 포스트잇(P10-4) — 교사가 자유 배치·그룹화, 학생도 실시간으로 본다.
/// 좌표(x,y)는 보드 영역 기준 0..1 정규화.
class LessonIdea {
  final String id;
  final String lessonId;
  final String slideId;
  final String teacherUid; // 비정규화(규칙: 교사 정리 허용)
  final String authorUid;
  final String authorName;
  final String text;
  final String color; // 포스트잇 색
  final String groupId; // 그룹 묶음(빈 문자열=미분류)
  final double x;
  final double y;
  final double scale;
  final double rotation; // 라디안
  final bool locked;
  final int zIndex;
  final DateTime? createdAt;

  const LessonIdea({
    required this.id,
    required this.lessonId,
    required this.slideId,
    required this.teacherUid,
    required this.authorUid,
    this.authorName = '',
    this.text = '',
    this.color = 'yellow',
    this.groupId = '',
    this.x = 0.5,
    this.y = 0.5,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.locked = false,
    this.zIndex = 0,
    this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'lessonId': lessonId,
        'slideId': slideId,
        'teacherUid': teacherUid,
        'authorUid': authorUid,
        'authorName': authorName,
        'text': text,
        'color': color,
        'groupId': groupId,
        'x': x,
        'y': y,
        'scale': scale,
        'rotation': rotation,
        'locked': locked,
        'zIndex': zIndex,
        'createdAt': createdAt?.toIso8601String(),
      };

  factory LessonIdea.fromMap(Map<String, dynamic> m) => LessonIdea(
        id: m['id'] as String? ?? '',
        lessonId: m['lessonId'] as String? ?? '',
        slideId: m['slideId'] as String? ?? '',
        teacherUid: m['teacherUid'] as String? ?? '',
        authorUid: m['authorUid'] as String? ?? '',
        authorName: m['authorName'] as String? ?? '',
        text: m['text'] as String? ?? '',
        color: m['color'] as String? ?? 'yellow',
        groupId: m['groupId'] as String? ?? '',
        x: (m['x'] as num?)?.toDouble() ?? 0.5,
        y: (m['y'] as num?)?.toDouble() ?? 0.5,
        scale: (m['scale'] as num?)?.toDouble() ?? 1.0,
        rotation: (m['rotation'] as num?)?.toDouble() ?? 0.0,
        locked: m['locked'] as bool? ?? false,
        zIndex: (m['zIndex'] as num?)?.toInt() ?? 0,
        createdAt: (m['createdAt'] as String?) != null ? DateTime.tryParse(m['createdAt'] as String) : null,
      );
}

/// 좋아요 반응(P10-4) — 학생 1명이 한 대상(targetId)에 한 emoji 1개(토글).
class LessonReaction {
  final String id;
  final String lessonId;
  final String targetId; // 반응 대상(아이디어/응답 id)
  final String emoji;
  final String studentUid;

  const LessonReaction({
    required this.id,
    required this.lessonId,
    required this.targetId,
    required this.emoji,
    required this.studentUid,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'lessonId': lessonId,
        'targetId': targetId,
        'emoji': emoji,
        'studentUid': studentUid,
      };

  factory LessonReaction.fromMap(Map<String, dynamic> m) => LessonReaction(
        id: m['id'] as String? ?? '',
        lessonId: m['lessonId'] as String? ?? '',
        targetId: m['targetId'] as String? ?? '',
        emoji: m['emoji'] as String? ?? '',
        studentUid: m['studentUid'] as String? ?? '',
      );
}

/// 실시간 집계(워드클라우드·투표·요약) — 순수 함수, 단위 테스트 가능.
class LiveAggregate {
  LiveAggregate._();

  /// 반응 목록 → 대상별 emoji 카운트. {targetId: {emoji: count}}.
  static Map<String, Map<String, int>> reactionCounts(Iterable<LessonReaction> rs) {
    final out = <String, Map<String, int>>{};
    for (final r in rs) {
      if (r.targetId.isEmpty || r.emoji.isEmpty) continue;
      final m = out.putIfAbsent(r.targetId, () => <String, int>{});
      m[r.emoji] = (m[r.emoji] ?? 0) + 1;
    }
    return out;
  }

  /// 제출 텍스트 빈도(워드클라우드/투표 공용). 앞뒤 공백 정리, 대소문자 통합.
  static Map<String, int> tally(Iterable<String> texts) {
    final out = <String, int>{};
    final display = <String, String>{}; // 표시용 원형(첫 등장)
    for (final raw in texts) {
      final t = raw.trim();
      if (t.isEmpty) continue;
      final key = t.toLowerCase();
      out[key] = (out[key] ?? 0) + 1;
      display.putIfAbsent(key, () => t);
    }
    return {for (final e in out.entries) display[e.key]!: e.value};
  }

  /// 빈도 내림차순 상위 N(동률은 가나다/사전순).
  static List<MapEntry<String, int>> top(Map<String, int> counts, [int n = 30]) {
    final list = counts.entries.toList()
      ..sort((a, b) => a.value == b.value ? a.key.compareTo(b.key) : b.value.compareTo(a.value));
    return list.take(n).toList();
  }

  /// AI 미연결 시 폴백 요약 — 상위 키워드로 한 문장.
  static String heuristicSummary(Iterable<String> texts) {
    final ranked = top(tally(texts), 3);
    if (ranked.isEmpty) return '아직 모인 답변이 없어요.';
    final words = ranked.map((e) => e.key).join(', ');
    return '학생들은 주로 $words 을(를) 중심으로 답했어요.';
  }
}
