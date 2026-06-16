// 학습지 제출(P3-1).

class WorksheetSubmission {
  final String id; // '{worksheetId}_{studentUid}'
  final String worksheetId;
  final String teacherUid; // 비정규화(교사 결과 조회용)
  final String studentUid;
  final String studentName;
  final Map<String, String> answers; // questionId → 학생 답
  final int score; // 맞은 자동채점 문항 수
  final int total; // 자동채점 문항 수
  final DateTime? submittedAt;

  const WorksheetSubmission({
    required this.id,
    required this.worksheetId,
    required this.teacherUid,
    required this.studentUid,
    this.studentName = '',
    this.answers = const {},
    this.score = 0,
    this.total = 0,
    this.submittedAt,
  });

  static String idFor(String worksheetId, String studentUid) => '${worksheetId}_$studentUid';

  Map<String, dynamic> toMap() => {
        'id': id,
        'worksheetId': worksheetId,
        'teacherUid': teacherUid,
        'studentUid': studentUid,
        'studentName': studentName,
        'answers': answers,
        'score': score,
        'total': total,
        'submittedAt': submittedAt?.toIso8601String(),
      };

  factory WorksheetSubmission.fromMap(Map<String, dynamic> m) => WorksheetSubmission(
        id: m['id'] as String? ?? '',
        worksheetId: m['worksheetId'] as String? ?? '',
        teacherUid: m['teacherUid'] as String? ?? '',
        studentUid: m['studentUid'] as String? ?? '',
        studentName: m['studentName'] as String? ?? '',
        answers: (m['answers'] as Map?)?.map((k, v) => MapEntry(k as String, v?.toString() ?? '')) ?? const {},
        score: (m['score'] as num?)?.toInt() ?? 0,
        total: (m['total'] as num?)?.toInt() ?? 0,
        submittedAt: (m['submittedAt'] as String?) != null ? DateTime.tryParse(m['submittedAt'] as String) : null,
      );
}
