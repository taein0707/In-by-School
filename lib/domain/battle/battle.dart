// 단어 경쟁전(Phase C) — 기존 플래시카드 단어 세트를 재사용한 학습 챌린지.
// "퀴즈 배틀"이 아니라 복습 참여율을 높이는 교육 기능. 게임처럼 보이지 않게 설계.
//
//   battleSessions/{battleId}                 — 챌린지 메타 + 생성된 문제 목록
//   battleSessions/{battleId}/players/{uid}   — 참가자 1명의 진행/점수
//
// 신규 컬렉션은 battleSessions 만 추가하고, 단어는 flashcardDecks/Cards 를 그대로 재사용한다.

enum BattleStatus {
  lobby, // 생성됨(참가 대기)
  running, // 진행 중
  ended; // 종료

  static BattleStatus fromName(String? s) =>
      values.firstWhere((e) => e.name == s, orElse: () => BattleStatus.lobby);
}

enum BattleDifficulty {
  easy, // 명확한 오답
  normal, // 유사 의미 포함
  hard; // 비슷한 철자·의미(혼동 유도)

  static BattleDifficulty fromName(String? s) =>
      values.firstWhere((e) => e.name == s, orElse: () => BattleDifficulty.normal);

  String get label => switch (this) {
        BattleDifficulty.easy => '쉬움',
        BattleDifficulty.normal => '보통',
        BattleDifficulty.hard => '어려움',
      };
}

enum BattleDirection {
  enToKo, // 영어 → 한국어
  koToEn, // 한국어 → 영어
  mixed; // 혼합

  static BattleDirection fromName(String? s) =>
      values.firstWhere((e) => e.name == s, orElse: () => BattleDirection.enToKo);

  String get label => switch (this) {
        BattleDirection.enToKo => '영어 → 한국어',
        BattleDirection.koToEn => '한국어 → 영어',
        BattleDirection.mixed => '혼합',
      };
}

enum BattleQType {
  choice, // 선택형(4지선다)
  short; // 단답형

  static BattleQType fromName(String? s) =>
      values.firstWhere((e) => e.name == s, orElse: () => BattleQType.choice);
}

/// 생성된 문제 1개(모든 참가자가 동일 문제를 풀도록 세션 문서에 저장).
class BattleQuestion {
  final String prompt; // 제시어
  final String answer; // 정답
  final List<String> choices; // 선택형: 4지선다(정답 포함) · 단답형: 빈 리스트
  final BattleQType type;

  const BattleQuestion({
    required this.prompt,
    required this.answer,
    this.choices = const [],
    this.type = BattleQType.choice,
  });

  Map<String, dynamic> toMap() => {
        'prompt': prompt,
        'answer': answer,
        'choices': choices,
        'type': type.name,
      };

  factory BattleQuestion.fromMap(Map<String, dynamic> m) => BattleQuestion(
        prompt: m['prompt'] as String? ?? '',
        answer: m['answer'] as String? ?? '',
        choices: (m['choices'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        type: BattleQType.fromName(m['type'] as String?),
      );
}

/// 경쟁전 세션.
class BattleSession {
  final String id;
  final String title;
  final String teacherUid;
  final String deckId;
  final String joinCode; // 참가 코드(대문자 6자)
  final BattleStatus status;
  final int questionCount;
  final int timeLimitSec; // 0 = 제한 없음
  final BattleDifficulty difficulty;
  final int choiceRatio; // 선택형 비율 0~100
  final BattleDirection direction;
  final List<BattleQuestion> questions;
  final DateTime? createdAt;
  final DateTime? startAt;
  final DateTime? endAt;

  const BattleSession({
    required this.id,
    this.title = '',
    required this.teacherUid,
    required this.deckId,
    this.joinCode = '',
    this.status = BattleStatus.lobby,
    this.questionCount = 0,
    this.timeLimitSec = 0,
    this.difficulty = BattleDifficulty.normal,
    this.choiceRatio = 100,
    this.direction = BattleDirection.enToKo,
    this.questions = const [],
    this.createdAt,
    this.startAt,
    this.endAt,
  });

  bool get unlimitedTime => timeLimitSec <= 0;

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'teacherUid': teacherUid,
        'deckId': deckId,
        'joinCode': joinCode,
        'status': status.name,
        'questionCount': questionCount,
        'timeLimitSec': timeLimitSec,
        'difficulty': difficulty.name,
        'choiceRatio': choiceRatio,
        'direction': direction.name,
        'questions': questions.map((q) => q.toMap()).toList(),
        'createdAt': createdAt?.toIso8601String(),
        'startAt': startAt?.toIso8601String(),
        'endAt': endAt?.toIso8601String(),
      };

  factory BattleSession.fromMap(Map<String, dynamic> m) => BattleSession(
        id: m['id'] as String? ?? '',
        title: m['title'] as String? ?? '',
        teacherUid: m['teacherUid'] as String? ?? '',
        deckId: m['deckId'] as String? ?? '',
        joinCode: m['joinCode'] as String? ?? '',
        status: BattleStatus.fromName(m['status'] as String?),
        questionCount: (m['questionCount'] as num?)?.toInt() ?? 0,
        timeLimitSec: (m['timeLimitSec'] as num?)?.toInt() ?? 0,
        difficulty: BattleDifficulty.fromName(m['difficulty'] as String?),
        choiceRatio: (m['choiceRatio'] as num?)?.toInt() ?? 100,
        direction: BattleDirection.fromName(m['direction'] as String?),
        questions: (m['questions'] as List?)
                ?.map((e) => BattleQuestion.fromMap((e as Map).cast<String, dynamic>()))
                .toList() ??
            const [],
        createdAt: (m['createdAt'] as String?) != null ? DateTime.tryParse(m['createdAt'] as String) : null,
        startAt: (m['startAt'] as String?) != null ? DateTime.tryParse(m['startAt'] as String) : null,
        endAt: (m['endAt'] as String?) != null ? DateTime.tryParse(m['endAt'] as String) : null,
      );
}

/// 참가자 1명의 진행/점수. battleSessions/{id}/players/{uid}.
class BattlePlayer {
  final String uid;
  final String nickname;
  final int score;
  final int streak; // 현재 연속 정답
  final int maxStreak;
  final int correctCount;
  final int wrongCount;
  final int durationSeconds;
  final bool finished;
  final DateTime? joinedAt;
  final DateTime? submittedAt;

  const BattlePlayer({
    required this.uid,
    this.nickname = '',
    this.score = 0,
    this.streak = 0,
    this.maxStreak = 0,
    this.correctCount = 0,
    this.wrongCount = 0,
    this.durationSeconds = 0,
    this.finished = false,
    this.joinedAt,
    this.submittedAt,
  });

  int get answered => correctCount + wrongCount;

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'nickname': nickname,
        'score': score,
        'streak': streak,
        'maxStreak': maxStreak,
        'correctCount': correctCount,
        'wrongCount': wrongCount,
        'durationSeconds': durationSeconds,
        'finished': finished,
        'joinedAt': joinedAt?.toIso8601String(),
        'submittedAt': submittedAt?.toIso8601String(),
      };

  factory BattlePlayer.fromMap(Map<String, dynamic> m) => BattlePlayer(
        uid: m['uid'] as String? ?? '',
        nickname: m['nickname'] as String? ?? '',
        score: (m['score'] as num?)?.toInt() ?? 0,
        streak: (m['streak'] as num?)?.toInt() ?? 0,
        maxStreak: (m['maxStreak'] as num?)?.toInt() ?? 0,
        correctCount: (m['correctCount'] as num?)?.toInt() ?? 0,
        wrongCount: (m['wrongCount'] as num?)?.toInt() ?? 0,
        durationSeconds: (m['durationSeconds'] as num?)?.toInt() ?? 0,
        finished: m['finished'] as bool? ?? false,
        joinedAt: (m['joinedAt'] as String?) != null ? DateTime.tryParse(m['joinedAt'] as String) : null,
        submittedAt: (m['submittedAt'] as String?) != null ? DateTime.tryParse(m['submittedAt'] as String) : null,
      );
}
