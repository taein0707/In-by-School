// 학습지 문항(P3-1) + 자동 채점 로직.

enum WorksheetQuestionType {
  multipleChoice, // 객관식
  shortAnswer, // 단답형
  ox, // OX
  essay; // 서술형(자동 채점 제외)

  static WorksheetQuestionType fromName(String? s) =>
      values.firstWhere((e) => e.name == s, orElse: () => WorksheetQuestionType.multipleChoice);

  String get label => switch (this) {
        WorksheetQuestionType.multipleChoice => '객관식',
        WorksheetQuestionType.shortAnswer => '단답형',
        WorksheetQuestionType.ox => 'OX',
        WorksheetQuestionType.essay => '서술형',
      };

  /// 자동 채점 대상인가(서술형 제외).
  bool get autoGraded => this != WorksheetQuestionType.essay;
}

class WorksheetQuestion {
  final String id;
  final String worksheetId;
  final String teacherUid; // 비정규화(보안규칙용)
  final WorksheetQuestionType type;
  final String question;
  final List<String> choices; // 객관식 보기(OX/단답/서술은 빈 리스트)
  final String answer; // 정답(서술형은 빈 문자열 가능)
  final int order;

  const WorksheetQuestion({
    required this.id,
    required this.worksheetId,
    required this.teacherUid,
    this.type = WorksheetQuestionType.multipleChoice,
    this.question = '',
    this.choices = const [],
    this.answer = '',
    this.order = 0,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'worksheetId': worksheetId,
        'teacherUid': teacherUid,
        'type': type.name,
        'question': question,
        'choices': choices,
        'answer': answer,
        'order': order,
      };

  factory WorksheetQuestion.fromMap(Map<String, dynamic> m) => WorksheetQuestion(
        id: m['id'] as String? ?? '',
        worksheetId: m['worksheetId'] as String? ?? '',
        teacherUid: m['teacherUid'] as String? ?? '',
        type: WorksheetQuestionType.fromName(m['type'] as String?),
        question: m['question'] as String? ?? '',
        choices: (m['choices'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        answer: m['answer'] as String? ?? '',
        order: (m['order'] as num?)?.toInt() ?? 0,
      );

  /// 주어진 답이 정답인지(자동 채점). 단답형은 공백·대소문자 무시, 그 외 정확 일치.
  bool isCorrect(String given) {
    if (!type.autoGraded) return false;
    final g = given.trim();
    final a = answer.trim();
    if (type == WorksheetQuestionType.shortAnswer) {
      return g.toLowerCase() == a.toLowerCase();
    }
    return g == a;
  }
}

/// 학습지 자동 채점 — 서술형은 점수/분모에서 제외.
class WorksheetGrading {
  WorksheetGrading._();

  /// 반환: (score=맞은 자동채점 문항 수, total=자동채점 문항 수).
  static ({int score, int total}) grade(List<WorksheetQuestion> questions, Map<String, String> answers) {
    var score = 0, total = 0;
    for (final q in questions) {
      if (!q.type.autoGraded) continue;
      total++;
      final given = answers[q.id];
      if (given != null && q.isCorrect(given)) score++;
    }
    return (score: score, total: total);
  }
}
