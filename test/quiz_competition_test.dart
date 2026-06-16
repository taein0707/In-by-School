import 'package:flutter_test/flutter_test.dart';
import 'package:ocl_study/domain/engagement/quiz_competition.dart';
import 'package:ocl_study/domain/worksheet/worksheet_question.dart';

WorksheetQuestion _q(WorksheetQuestionType type, String answer, {List<String> choices = const []}) =>
    WorksheetQuestion(id: 't', worksheetId: 'w', teacherUid: 't', type: type, answer: answer, choices: choices);

void main() {
  group('QuizScoring.score', () {
    final questions = [
      _q(WorksheetQuestionType.multipleChoice, '서울', choices: ['서울', '부산']),
      _q(WorksheetQuestionType.ox, 'O'),
      _q(WorksheetQuestionType.shortAnswer, 'Apple'),
      _q(WorksheetQuestionType.essay, ''),
    ];

    test('counts correct auto-graded answers; essay ignored', () {
      final score = QuizScoring.score(questions, {0: '서울', 1: 'O', 2: 'apple', 3: '아무말'});
      expect(score, 3);
    });

    test('partial and missing', () {
      expect(QuizScoring.score(questions, {0: '서울', 1: 'X'}), 1);
      expect(QuizScoring.score(questions, const {}), 0);
    });
  });

  group('QuizScoring.canRetry', () {
    test('unlimited when maxAttempts <= 0', () {
      expect(QuizScoring.canRetry(99, 0), isTrue);
    });
    test('blocks once attempts reach the limit', () {
      expect(QuizScoring.canRetry(0, 1), isTrue);
      expect(QuizScoring.canRetry(1, 1), isFalse);
      expect(QuizScoring.canRetry(1, 2), isTrue);
      expect(QuizScoring.canRetry(2, 2), isFalse);
    });
  });

  group('QuizRanking.sorted', () {
    test('orders by score desc, then answered desc, then name', () {
      final players = [
        const QuizPlayer(id: 'a', competitionId: 'q', teacherUid: 't', studentUid: 'a', studentName: '가', score: 3, answered: 5),
        const QuizPlayer(id: 'b', competitionId: 'q', teacherUid: 't', studentUid: 'b', studentName: '나', score: 5, answered: 5),
        const QuizPlayer(id: 'c', competitionId: 'q', teacherUid: 't', studentUid: 'c', studentName: '다', score: 5, answered: 3),
      ];
      final r = QuizRanking.sorted(players);
      expect(r.map((p) => p.studentName).toList(), ['나', '다', '가']);
    });
  });

  group('QuizCompetition timing', () {
    final start = DateTime.parse('2026-06-13T09:00:00.000');
    QuizCompetition comp(QuizStatus status) => QuizCompetition(
          id: 'q', classroomId: 'c', teacherUid: 't', durationSec: 60, status: status, startedAt: start);

    test('remaining before start returns full duration', () {
      const c = QuizCompetition(id: 'q', classroomId: 'c', teacherUid: 't', durationSec: 60);
      expect(c.remaining(start).inSeconds, 60);
    });

    test('remaining counts down and clamps at zero', () {
      final c = comp(QuizStatus.playing);
      expect(c.remaining(start.add(const Duration(seconds: 20))).inSeconds, 40);
      expect(c.remaining(start.add(const Duration(seconds: 90))).inSeconds, 0);
    });

    test('isExpired only while playing and past the end', () {
      expect(comp(QuizStatus.playing).isExpired(start.add(const Duration(seconds: 30))), isFalse);
      expect(comp(QuizStatus.playing).isExpired(start.add(const Duration(seconds: 61))), isTrue);
      expect(comp(QuizStatus.finished).isExpired(start.add(const Duration(seconds: 61))), isFalse);
    });
  });

  group('serialization', () {
    test('competition round-trips with embedded questions', () {
      final c = QuizCompetition(
        id: 'q1',
        classroomId: 'c1',
        teacherUid: 't1',
        title: '단원평가',
        questions: [_q(WorksheetQuestionType.ox, 'O')],
        durationSec: 120,
        maxAttempts: 2,
        status: QuizStatus.playing,
        startedAt: DateTime.parse('2026-06-13T09:00:00.000'),
        createdAt: DateTime.parse('2026-06-13T08:00:00.000'),
      );
      final back = QuizCompetition.fromMap(c.toMap());
      expect(back.title, '단원평가');
      expect(back.durationSec, 120);
      expect(back.maxAttempts, 2);
      expect(back.status, QuizStatus.playing);
      expect(back.questions.length, 1);
      expect(back.questions.first.type, WorksheetQuestionType.ox);
    });

    test('player round-trips and idFor is deterministic', () {
      expect(QuizPlayer.idFor('q1', 'u1'), 'q1_u1');
      const p = QuizPlayer(
        id: 'q1_u1', competitionId: 'q1', teacherUid: 't1', studentUid: 'u1',
        studentName: '가', score: 4, answered: 5, attempts: 1, finished: true);
      final back = QuizPlayer.fromMap(p.toMap());
      expect(back.score, 4);
      expect(back.answered, 5);
      expect(back.attempts, 1);
      expect(back.finished, isTrue);
    });
  });
}
