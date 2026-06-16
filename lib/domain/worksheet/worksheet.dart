// 온라인 학습지(Worksheet, P3-1) — Classroom 기반. 교사가 학습지를 만들고 문항을 추가,
// 학생이 설문 스타일로 풀이·제출, 자동 채점. 신규 컬렉션만 추가(기존 구조 변경 없음).
//
//   worksheets/{id}            { classroomId, teacherUid, title, description, createdAt, updatedAt }
//   worksheetQuestions/{id}    { worksheetId, teacherUid, type, question, choices[], answer, order }
//   worksheetSubmissions/{id}  { worksheetId, studentUid, teacherUid, studentName, answers{}, score, total, submittedAt }

class Worksheet {
  final String id;
  final String classroomId;
  final String teacherUid;
  final String title;
  final String description;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Worksheet({
    required this.id,
    required this.classroomId,
    required this.teacherUid,
    this.title = '',
    this.description = '',
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'classroomId': classroomId,
        'teacherUid': teacherUid,
        'title': title,
        'description': description,
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory Worksheet.fromMap(Map<String, dynamic> m) => Worksheet(
        id: m['id'] as String? ?? '',
        classroomId: m['classroomId'] as String? ?? '',
        teacherUid: m['teacherUid'] as String? ?? '',
        title: m['title'] as String? ?? '',
        description: m['description'] as String? ?? '',
        createdAt: (m['createdAt'] as String?) != null ? DateTime.tryParse(m['createdAt'] as String) : null,
        updatedAt: (m['updatedAt'] as String?) != null ? DateTime.tryParse(m['updatedAt'] as String) : null,
      );
}
