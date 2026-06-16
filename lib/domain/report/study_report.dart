// 스터디 플래너(Phase S) — 학생이 공부 후 작성하는 자동 학습 기록.
// 최상위 컬렉션 studyReports/{id}. 숙제/제출과 동일 패턴으로 teacherUid 를
// 비정규화해 보안규칙이 get() 없이 평가되도록 한다.

enum ReportStatus {
  draft, // 임시 저장(학생만)
  submitted; // 선생님께 제출됨

  static ReportStatus fromName(String? s) =>
      values.firstWhere((e) => e.name == s, orElse: () => ReportStatus.draft);
}

/// 학생 1명의 하루 학습 기록.
class StudyReport {
  final String id;
  final String studentUid;
  final String teacherUid; // 제출 대상 선생님(연결된 교사). 무소속이면 ''.
  final String studentName;
  final String subject;
  final int studyMinutes;
  final String content; // 자동 생성 후 학생이 수정 가능한 본문
  final ReportStatus status;
  final DateTime? submittedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const StudyReport({
    required this.id,
    required this.studentUid,
    this.teacherUid = '',
    this.studentName = '',
    this.subject = '',
    this.studyMinutes = 0,
    this.content = '',
    this.status = ReportStatus.draft,
    this.submittedAt,
    this.createdAt,
    this.updatedAt,
  });

  bool get isSubmitted => status == ReportStatus.submitted;

  StudyReport copyWith({
    String? subject,
    int? studyMinutes,
    String? content,
    ReportStatus? status,
    String? teacherUid,
    DateTime? submittedAt,
    DateTime? updatedAt,
  }) =>
      StudyReport(
        id: id,
        studentUid: studentUid,
        teacherUid: teacherUid ?? this.teacherUid,
        studentName: studentName,
        subject: subject ?? this.subject,
        studyMinutes: studyMinutes ?? this.studyMinutes,
        content: content ?? this.content,
        status: status ?? this.status,
        submittedAt: submittedAt ?? this.submittedAt,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'studentUid': studentUid,
        'teacherUid': teacherUid,
        'studentName': studentName,
        'subject': subject,
        'studyMinutes': studyMinutes,
        'content': content,
        'status': status.name,
        'submittedAt': submittedAt?.toIso8601String(),
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory StudyReport.fromMap(Map<String, dynamic> m) => StudyReport(
        id: m['id'] as String? ?? '',
        studentUid: m['studentUid'] as String? ?? '',
        teacherUid: m['teacherUid'] as String? ?? '',
        studentName: m['studentName'] as String? ?? '',
        subject: m['subject'] as String? ?? '',
        studyMinutes: (m['studyMinutes'] as num?)?.toInt() ?? 0,
        content: m['content'] as String? ?? '',
        status: ReportStatus.fromName(m['status'] as String?),
        submittedAt: (m['submittedAt'] as String?) != null
            ? DateTime.tryParse(m['submittedAt'] as String)
            : null,
        createdAt: (m['createdAt'] as String?) != null
            ? DateTime.tryParse(m['createdAt'] as String)
            : null,
        updatedAt: (m['updatedAt'] as String?) != null
            ? DateTime.tryParse(m['updatedAt'] as String)
            : null,
      );
}
