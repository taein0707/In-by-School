// AI 생성 문제(Phase 3) — 선생님이 주제(또는 플래시카드 덱)·난이도·문제 수를 주면
// AI(GeminiService)가 생성, 학생에게 배포. 자동 채점 후 결과 저장.
//
// 숙제/플래시카드와 동일한 3-컬렉션 패턴:
//   aiQuestionSets/{setId}                   — 세트 메타(주제/난이도/문제 수/출처 덱/AI 비용)
//   aiQuestions/{questionId}                 — 문제(유형/지문/보기/정답/해설) · setId 로 묶음
//   aiQuestionResults/{setId}_{studentUid}   — 학생별 풀이/자동 채점 결과
//
// 자동 채점을 위해 서술형 대신 객관식·단답형·빈칸(정답 비교 가능)만 지원한다.

import '../assignment/assignment.dart' show Difficulty;

enum QuestionType {
  multipleChoice, // 객관식
  shortAnswer, // 단답형
  fillBlank; // 빈칸 채우기

  String get label => switch (this) {
        QuestionType.multipleChoice => '객관식',
        QuestionType.shortAnswer => '단답형',
        QuestionType.fillBlank => '빈칸 채우기',
      };

  static QuestionType fromName(String? s) =>
      values.firstWhere((e) => e.name == s, orElse: () => QuestionType.multipleChoice);
}

/// 채점용 정규화 — 공백 정리, 소문자, 양끝 구두점 제거.
String normalizeAnswer(String s) => s
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'\s+'), ' ')
    .replaceAll(RegExp(r'^[\s\p{P}]+|[\s\p{P}]+$', unicode: true), '');

class AiQuestion {
  final String id;
  final String setId;
  final QuestionType type;
  final String prompt; // 문제(빈칸형은 ____ 포함)
  final List<String> choices; // 객관식 보기
  final String answer; // 정답(객관식: 정답 보기 텍스트)
  final String explanation; // 해설
  final int order;

  const AiQuestion({
    this.id = '',
    this.setId = '',
    required this.type,
    required this.prompt,
    this.choices = const [],
    this.answer = '',
    this.explanation = '',
    this.order = 0,
  });

  /// 학생 응답 채점 — 유형 무관, 정규화 비교.
  bool isCorrect(String given) => normalizeAnswer(given) == normalizeAnswer(answer);

  AiQuestion copyWith({
    QuestionType? type,
    String? prompt,
    List<String>? choices,
    String? answer,
    String? explanation,
  }) =>
      AiQuestion(
        id: id,
        setId: setId,
        type: type ?? this.type,
        prompt: prompt ?? this.prompt,
        choices: choices ?? this.choices,
        answer: answer ?? this.answer,
        explanation: explanation ?? this.explanation,
        order: order,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'setId': setId,
        'type': type.name,
        'prompt': prompt,
        'choices': choices,
        'answer': answer,
        'explanation': explanation,
        'order': order,
      };

  factory AiQuestion.fromMap(Map<String, dynamic> m) => AiQuestion(
        id: m['id'] as String? ?? '',
        setId: m['setId'] as String? ?? '',
        type: QuestionType.fromName(m['type'] as String?),
        prompt: m['prompt'] as String? ?? '',
        choices: (m['choices'] as List?)?.whereType<String>().toList() ?? const [],
        answer: m['answer'] as String? ?? '',
        explanation: m['explanation'] as String? ?? '',
        order: (m['order'] as num?)?.toInt() ?? 0,
      );
}

class AiQuestionSet {
  final String id;
  final String teacherUid;
  final String teacherName;
  final String title;
  final String topic; // 주제/단원
  final Difficulty difficulty;
  final int questionCount; // 비정규화
  final String? sourceDeckId; // 플래시카드 연계 생성 시 출처 덱
  final List<String> studentUids;
  final DateTime? createdAt;
  // ---- AI 생성/비용 추적 ----
  final bool fallbackUsed; // AI 실패→오프라인 폴백으로 생성됨
  final String aiModel; // 사용 모델(빈 문자열=폴백)
  final int aiPromptTokens;
  final int aiCandidatesTokens;
  final int aiTotalTokens;

  const AiQuestionSet({
    required this.id,
    required this.teacherUid,
    this.teacherName = '',
    this.title = '',
    this.topic = '',
    this.difficulty = Difficulty.medium,
    this.questionCount = 0,
    this.sourceDeckId,
    this.studentUids = const [],
    this.createdAt,
    this.fallbackUsed = false,
    this.aiModel = '',
    this.aiPromptTokens = 0,
    this.aiCandidatesTokens = 0,
    this.aiTotalTokens = 0,
  });

  bool get fromDeck => (sourceDeckId ?? '').isNotEmpty;

  Map<String, dynamic> toMap() => {
        'id': id,
        'teacherUid': teacherUid,
        'teacherName': teacherName,
        'title': title,
        'topic': topic,
        'difficulty': difficulty.name,
        'questionCount': questionCount,
        'sourceDeckId': sourceDeckId,
        'studentUids': studentUids,
        'createdAt': createdAt?.toIso8601String(),
        'fallbackUsed': fallbackUsed,
        'aiModel': aiModel,
        'aiPromptTokens': aiPromptTokens,
        'aiCandidatesTokens': aiCandidatesTokens,
        'aiTotalTokens': aiTotalTokens,
      };

  factory AiQuestionSet.fromMap(Map<String, dynamic> m) => AiQuestionSet(
        id: m['id'] as String? ?? '',
        teacherUid: m['teacherUid'] as String? ?? '',
        teacherName: m['teacherName'] as String? ?? '',
        title: m['title'] as String? ?? '',
        topic: m['topic'] as String? ?? '',
        difficulty: Difficulty.fromName(m['difficulty'] as String?),
        questionCount: (m['questionCount'] as num?)?.toInt() ?? 0,
        sourceDeckId: m['sourceDeckId'] as String?,
        studentUids: (m['studentUids'] as List?)?.whereType<String>().toList() ?? const [],
        createdAt: (m['createdAt'] as String?) != null
            ? DateTime.tryParse(m['createdAt'] as String)
            : null,
        fallbackUsed: m['fallbackUsed'] as bool? ?? false,
        aiModel: m['aiModel'] as String? ?? '',
        aiPromptTokens: (m['aiPromptTokens'] as num?)?.toInt() ?? 0,
        aiCandidatesTokens: (m['aiCandidatesTokens'] as num?)?.toInt() ?? 0,
        aiTotalTokens: (m['aiTotalTokens'] as num?)?.toInt() ?? 0,
      );
}

/// 한 문제에 대한 학생 응답 + 채점 결과.
class QuestionResponse {
  final String given; // 학생 응답
  final bool correct;
  const QuestionResponse({required this.given, required this.correct});

  Map<String, dynamic> toMap() => {'given': given, 'correct': correct};
  factory QuestionResponse.fromMap(Map<String, dynamic> m) =>
      QuestionResponse(given: m['given'] as String? ?? '', correct: m['correct'] as bool? ?? false);
}

/// 학생 1명의 한 세트 풀이 결과. aiQuestionResults/{setId}_{studentUid}.
class AiQuestionResult {
  final String id;
  final String setId;
  final String teacherUid;
  final String studentUid;
  final String studentName;
  final int total;
  final int correctCount;
  final List<QuestionResponse> responses;
  final DateTime? completedAt;
  final DateTime? updatedAt;

  const AiQuestionResult({
    required this.id,
    required this.setId,
    required this.teacherUid,
    required this.studentUid,
    this.studentName = '',
    this.total = 0,
    this.correctCount = 0,
    this.responses = const [],
    this.completedAt,
    this.updatedAt,
  });

  static String idFor(String setId, String studentUid) => '${setId}_$studentUid';

  bool get isDone => completedAt != null;
  double get correctRate => total == 0 ? 0 : correctCount / total;
  int get correctPercent => (correctRate * 100).round();

  Map<String, dynamic> toMap() => {
        'id': id,
        'setId': setId,
        'teacherUid': teacherUid,
        'studentUid': studentUid,
        'studentName': studentName,
        'total': total,
        'correctCount': correctCount,
        'responses': responses.map((r) => r.toMap()).toList(),
        'completedAt': completedAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory AiQuestionResult.fromMap(Map<String, dynamic> m) => AiQuestionResult(
        id: m['id'] as String? ?? '',
        setId: m['setId'] as String? ?? '',
        teacherUid: m['teacherUid'] as String? ?? '',
        studentUid: m['studentUid'] as String? ?? '',
        studentName: m['studentName'] as String? ?? '',
        total: (m['total'] as num?)?.toInt() ?? 0,
        correctCount: (m['correctCount'] as num?)?.toInt() ?? 0,
        responses: (m['responses'] as List?)
                ?.whereType<Map>()
                .map((r) => QuestionResponse.fromMap(r.cast<String, dynamic>()))
                .toList() ??
            const [],
        completedAt: (m['completedAt'] as String?) != null
            ? DateTime.tryParse(m['completedAt'] as String)
            : null,
        updatedAt: (m['updatedAt'] as String?) != null
            ? DateTime.tryParse(m['updatedAt'] as String)
            : null,
      );
}
