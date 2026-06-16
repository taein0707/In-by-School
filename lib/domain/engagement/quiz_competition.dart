// 수업 퀴즈 대회(P4-3) — quizCompetitions / quizCompetitionPlayers.
// 문제는 학습지(P3-1)의 자동 채점 문항을 스냅샷해서 사용(AI 미사용).
import '../worksheet/worksheet_question.dart';

enum QuizStatus {
  waiting,
  playing,
  finished;

  static QuizStatus fromName(String? s) =>
      values.firstWhere((e) => e.name == s, orElse: () => QuizStatus.waiting);
}

class QuizCompetition {
  final String id;
  final String classroomId;
  final String teacherUid;
  final String title;
  final List<WorksheetQuestion> questions; // 스냅샷(자동 채점 문항)
  final int durationSec; // 전체 제한 시간
  final int maxAttempts; // 재도전 제한(0 = 무제한)
  final QuizStatus status;
  final DateTime? startedAt;
  final DateTime? createdAt;

  const QuizCompetition({
    required this.id,
    required this.classroomId,
    required this.teacherUid,
    this.title = '',
    this.questions = const [],
    this.durationSec = 60,
    this.maxAttempts = 1,
    this.status = QuizStatus.waiting,
    this.startedAt,
    this.createdAt,
  });

  int get total => questions.length;

  /// 남은 시간(시작 전이면 전체, 만료면 0).
  Duration remaining(DateTime now) {
    if (startedAt == null) return Duration(seconds: durationSec);
    final end = startedAt!.add(Duration(seconds: durationSec));
    final r = end.difference(now);
    return r.isNegative ? Duration.zero : r;
  }

  /// 진행 중이면서 시간이 모두 지났는가(자동 종료 판정).
  bool isExpired(DateTime now) =>
      status == QuizStatus.playing &&
      startedAt != null &&
      now.isAfter(startedAt!.add(Duration(seconds: durationSec)));

  Map<String, dynamic> toMap() => {
        'id': id,
        'classroomId': classroomId,
        'teacherUid': teacherUid,
        'title': title,
        'questions': questions.map((q) => q.toMap()).toList(),
        'durationSec': durationSec,
        'maxAttempts': maxAttempts,
        'status': status.name,
        'startedAt': startedAt?.toIso8601String(),
        'createdAt': createdAt?.toIso8601String(),
      };

  factory QuizCompetition.fromMap(Map<String, dynamic> m) => QuizCompetition(
        id: m['id'] as String? ?? '',
        classroomId: m['classroomId'] as String? ?? '',
        teacherUid: m['teacherUid'] as String? ?? '',
        title: m['title'] as String? ?? '',
        questions: (m['questions'] as List?)
                ?.map((e) => WorksheetQuestion.fromMap(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            const [],
        durationSec: (m['durationSec'] as num?)?.toInt() ?? 60,
        maxAttempts: (m['maxAttempts'] as num?)?.toInt() ?? 1,
        status: QuizStatus.fromName(m['status'] as String?),
        startedAt: (m['startedAt'] as String?) != null ? DateTime.tryParse(m['startedAt'] as String) : null,
        createdAt: (m['createdAt'] as String?) != null ? DateTime.tryParse(m['createdAt'] as String) : null,
      );
}

class QuizPlayer {
  final String id; // '{competitionId}_{studentUid}'
  final String competitionId;
  final String teacherUid; // 비정규화(교사 조회/삭제용)
  final String studentUid;
  final String studentName;
  final int score;
  final int answered;
  final int attempts; // 시도 횟수(재도전 제한)
  final bool finished;
  final DateTime? updatedAt;

  const QuizPlayer({
    required this.id,
    required this.competitionId,
    required this.teacherUid,
    required this.studentUid,
    this.studentName = '',
    this.score = 0,
    this.answered = 0,
    this.attempts = 0,
    this.finished = false,
    this.updatedAt,
  });

  static String idFor(String competitionId, String studentUid) => '${competitionId}_$studentUid';

  Map<String, dynamic> toMap() => {
        'id': id,
        'competitionId': competitionId,
        'teacherUid': teacherUid,
        'studentUid': studentUid,
        'studentName': studentName,
        'score': score,
        'answered': answered,
        'attempts': attempts,
        'finished': finished,
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory QuizPlayer.fromMap(Map<String, dynamic> m) => QuizPlayer(
        id: m['id'] as String? ?? '',
        competitionId: m['competitionId'] as String? ?? '',
        teacherUid: m['teacherUid'] as String? ?? '',
        studentUid: m['studentUid'] as String? ?? '',
        studentName: m['studentName'] as String? ?? '',
        score: (m['score'] as num?)?.toInt() ?? 0,
        answered: (m['answered'] as num?)?.toInt() ?? 0,
        attempts: (m['attempts'] as num?)?.toInt() ?? 0,
        finished: m['finished'] as bool? ?? false,
        updatedAt: (m['updatedAt'] as String?) != null ? DateTime.tryParse(m['updatedAt'] as String) : null,
      );
}

/// 퀴즈 순수 로직(테스트 대상).
class QuizScoring {
  QuizScoring._();

  /// 인덱스→답 맵으로 맞은 개수 계산(자동 채점 문항만).
  static int score(List<WorksheetQuestion> questions, Map<int, String> answers) {
    var correct = 0;
    for (var i = 0; i < questions.length; i++) {
      final q = questions[i];
      if (!q.type.autoGraded) continue;
      final given = answers[i];
      if (given != null && q.isCorrect(given)) correct++;
    }
    return correct;
  }

  /// 재도전 가능한가(maxAttempts==0 이면 무제한).
  static bool canRetry(int attempts, int maxAttempts) => maxAttempts <= 0 || attempts < maxAttempts;
}

/// 랭킹 정렬: 점수 내림차순 → 푼 문항 많은 순 → 이름순.
class QuizRanking {
  QuizRanking._();

  static List<QuizPlayer> sorted(List<QuizPlayer> players) {
    final list = [...players];
    list.sort((a, b) {
      if (a.score != b.score) return b.score.compareTo(a.score);
      if (a.answered != b.answered) return b.answered.compareTo(a.answered);
      return a.studentName.compareTo(b.studentName);
    });
    return list;
  }
}
