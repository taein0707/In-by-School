// 숙제 — 선생님이 만들어 학생들에게 배포. 최상위 컬렉션 assignments/{id}.
// 학생별 진행/제출은 별도 submissions/{id} 문서로 분리(다대다 + 권한 분리).

enum AssignmentType {
  problemSet, // 문제집
  worksheet, // 학습지
  vocab, // 단어 암기
  review, // 오답 정리
  free; // 자유 과제

  String get label => switch (this) {
        AssignmentType.problemSet => '문제집',
        AssignmentType.worksheet => '학습지',
        AssignmentType.vocab => '단어 암기',
        AssignmentType.review => '오답 정리',
        AssignmentType.free => '자유 과제',
      };

  static AssignmentType fromName(String? s) =>
      values.firstWhere((e) => e.name == s, orElse: () => AssignmentType.free);
}

enum Difficulty {
  easy,
  medium,
  hard;

  String get label => switch (this) {
        Difficulty.easy => '쉬움',
        Difficulty.medium => '보통',
        Difficulty.hard => '어려움',
      };

  static Difficulty fromName(String? s) =>
      values.firstWhere((e) => e.name == s, orElse: () => Difficulty.medium);
}

class Assignment {
  final String id;
  final String teacherUid;
  final String teacherName;
  final String title;
  final String description;
  final AssignmentType type;
  final Difficulty difficulty;
  final int priority; // 0=보통, 1=중요, 2=긴급
  final DateTime? dueDate;
  final List<String> studentUids; // 배포 대상
  final DateTime? createdAt;

  const Assignment({
    required this.id,
    required this.teacherUid,
    this.teacherName = '',
    this.title = '',
    this.description = '',
    this.type = AssignmentType.free,
    this.difficulty = Difficulty.medium,
    this.priority = 0,
    this.dueDate,
    this.studentUids = const [],
    this.createdAt,
  });

  Assignment copyWith({
    String? title,
    String? description,
    AssignmentType? type,
    Difficulty? difficulty,
    int? priority,
    DateTime? dueDate,
    List<String>? studentUids,
  }) =>
      Assignment(
        id: id,
        teacherUid: teacherUid,
        teacherName: teacherName,
        title: title ?? this.title,
        description: description ?? this.description,
        type: type ?? this.type,
        difficulty: difficulty ?? this.difficulty,
        priority: priority ?? this.priority,
        dueDate: dueDate ?? this.dueDate,
        studentUids: studentUids ?? this.studentUids,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'teacherUid': teacherUid,
        'teacherName': teacherName,
        'title': title,
        'description': description,
        'type': type.name,
        'difficulty': difficulty.name,
        'priority': priority,
        'dueDate': dueDate?.toIso8601String(),
        'studentUids': studentUids,
        'createdAt': createdAt?.toIso8601String(),
      };

  factory Assignment.fromMap(Map<String, dynamic> m) => Assignment(
        id: m['id'] as String? ?? '',
        teacherUid: m['teacherUid'] as String? ?? '',
        teacherName: m['teacherName'] as String? ?? '',
        title: m['title'] as String? ?? '',
        description: m['description'] as String? ?? '',
        type: AssignmentType.fromName(m['type'] as String?),
        difficulty: Difficulty.fromName(m['difficulty'] as String?),
        priority: (m['priority'] as num?)?.toInt() ?? 0,
        dueDate: (m['dueDate'] as String?) != null
            ? DateTime.tryParse(m['dueDate'] as String)
            : null,
        studentUids: (m['studentUids'] as List?)?.whereType<String>().toList() ?? const [],
        createdAt: (m['createdAt'] as String?) != null
            ? DateTime.tryParse(m['createdAt'] as String)
            : null,
      );
}

enum SubmissionStatus {
  assigned, // 배포됨(미시작)
  inProgress, // 진행 중
  done; // 완료

  String get label => switch (this) {
        SubmissionStatus.assigned => '시작 전',
        SubmissionStatus.inProgress => '진행 중',
        SubmissionStatus.done => '완료',
      };

  static SubmissionStatus fromName(String? s) =>
      values.firstWhere((e) => e.name == s, orElse: () => SubmissionStatus.assigned);
}

/// 학생 1명의 한 숙제에 대한 진행/제출. submissions/{assignmentId}_{studentUid}.
class Submission {
  final String id; // '{assignmentId}_{studentUid}'
  final String assignmentId;
  final String teacherUid; // 알림/권한용 비정규화
  final String studentUid;
  final String studentName;
  final SubmissionStatus status;
  final int progress; // 0~100
  final String memo;
  final List<String> photoUrls; // 사진 제출
  final List<String> fileUrls; // 파일 제출
  final DateTime? completedAt;
  final DateTime? updatedAt;

  const Submission({
    required this.id,
    required this.assignmentId,
    required this.teacherUid,
    required this.studentUid,
    this.studentName = '',
    this.status = SubmissionStatus.assigned,
    this.progress = 0,
    this.memo = '',
    this.photoUrls = const [],
    this.fileUrls = const [],
    this.completedAt,
    this.updatedAt,
  });

  static String idFor(String assignmentId, String studentUid) => '${assignmentId}_$studentUid';

  bool get isDone => status == SubmissionStatus.done;

  Submission copyWith({
    SubmissionStatus? status,
    int? progress,
    String? memo,
    List<String>? photoUrls,
    List<String>? fileUrls,
    DateTime? completedAt,
    DateTime? updatedAt,
  }) =>
      Submission(
        id: id,
        assignmentId: assignmentId,
        teacherUid: teacherUid,
        studentUid: studentUid,
        studentName: studentName,
        status: status ?? this.status,
        progress: progress ?? this.progress,
        memo: memo ?? this.memo,
        photoUrls: photoUrls ?? this.photoUrls,
        fileUrls: fileUrls ?? this.fileUrls,
        completedAt: completedAt ?? this.completedAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'assignmentId': assignmentId,
        'teacherUid': teacherUid,
        'studentUid': studentUid,
        'studentName': studentName,
        'status': status.name,
        'progress': progress,
        'memo': memo,
        'photoUrls': photoUrls,
        'fileUrls': fileUrls,
        'completedAt': completedAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory Submission.fromMap(Map<String, dynamic> m) => Submission(
        id: m['id'] as String? ?? '',
        assignmentId: m['assignmentId'] as String? ?? '',
        teacherUid: m['teacherUid'] as String? ?? '',
        studentUid: m['studentUid'] as String? ?? '',
        studentName: m['studentName'] as String? ?? '',
        status: SubmissionStatus.fromName(m['status'] as String?),
        progress: (m['progress'] as num?)?.toInt() ?? 0,
        memo: m['memo'] as String? ?? '',
        photoUrls: (m['photoUrls'] as List?)?.whereType<String>().toList() ?? const [],
        fileUrls: (m['fileUrls'] as List?)?.whereType<String>().toList() ?? const [],
        completedAt: (m['completedAt'] as String?) != null
            ? DateTime.tryParse(m['completedAt'] as String)
            : null,
        updatedAt: (m['updatedAt'] as String?) != null
            ? DateTime.tryParse(m['updatedAt'] as String)
            : null,
      );
}
