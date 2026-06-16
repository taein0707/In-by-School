import 'package:flutter_test/flutter_test.dart';
import 'package:ocl_study/domain/worksheet/worksheet.dart';
import 'package:ocl_study/domain/worksheet/worksheet_question.dart';

void main() {
  group('WorksheetQuestionType', () {
    test('fromName round-trips known values, falls back to multipleChoice', () {
      for (final t in WorksheetQuestionType.values) {
        expect(WorksheetQuestionType.fromName(t.name), t);
      }
      expect(WorksheetQuestionType.fromName(null), WorksheetQuestionType.multipleChoice);
      expect(WorksheetQuestionType.fromName('garbage'), WorksheetQuestionType.multipleChoice);
    });

    test('only essay is excluded from auto grading', () {
      expect(WorksheetQuestionType.multipleChoice.autoGraded, isTrue);
      expect(WorksheetQuestionType.shortAnswer.autoGraded, isTrue);
      expect(WorksheetQuestionType.ox.autoGraded, isTrue);
      expect(WorksheetQuestionType.essay.autoGraded, isFalse);
    });
  });

  group('WorksheetQuestion.isCorrect', () {
    WorksheetQuestion q(WorksheetQuestionType type, String answer) =>
        WorksheetQuestion(id: 'q', worksheetId: 'w', teacherUid: 't', type: type, answer: answer);

    test('multiple choice requires exact match', () {
      final mc = q(WorksheetQuestionType.multipleChoice, '서울');
      expect(mc.isCorrect('서울'), isTrue);
      expect(mc.isCorrect(' 서울 '), isTrue); // trims
      expect(mc.isCorrect('부산'), isFalse);
    });

    test('short answer ignores case and surrounding whitespace', () {
      final sa = q(WorksheetQuestionType.shortAnswer, 'Apple');
      expect(sa.isCorrect('apple'), isTrue);
      expect(sa.isCorrect('  APPLE '), isTrue);
      expect(sa.isCorrect('apples'), isFalse);
    });

    test('ox requires exact match', () {
      final ox = q(WorksheetQuestionType.ox, 'O');
      expect(ox.isCorrect('O'), isTrue);
      expect(ox.isCorrect('X'), isFalse);
    });

    test('essay is never auto-correct', () {
      final essay = q(WorksheetQuestionType.essay, '');
      expect(essay.isCorrect('anything'), isFalse);
    });
  });

  group('WorksheetGrading.grade', () {
    final questions = [
      WorksheetQuestion(id: 'a', worksheetId: 'w', teacherUid: 't', type: WorksheetQuestionType.multipleChoice, answer: '서울'),
      WorksheetQuestion(id: 'b', worksheetId: 'w', teacherUid: 't', type: WorksheetQuestionType.shortAnswer, answer: 'Apple'),
      WorksheetQuestion(id: 'c', worksheetId: 'w', teacherUid: 't', type: WorksheetQuestionType.ox, answer: 'O'),
      WorksheetQuestion(id: 'd', worksheetId: 'w', teacherUid: 't', type: WorksheetQuestionType.essay, answer: ''),
    ];

    test('essay excluded from both score and total', () {
      final r = WorksheetGrading.grade(questions, {'a': '서울', 'b': 'apple', 'c': 'O', 'd': '아무말'});
      expect(r.score, 3);
      expect(r.total, 3); // essay not counted
    });

    test('partial and missing answers', () {
      final r = WorksheetGrading.grade(questions, {'a': '서울', 'c': 'X'});
      expect(r.score, 1); // only 'a' correct; 'b' missing, 'c' wrong
      expect(r.total, 3);
    });

    test('empty questions yields zero/zero', () {
      final r = WorksheetGrading.grade(const [], const {});
      expect(r.score, 0);
      expect(r.total, 0);
    });
  });

  group('Worksheet serialization', () {
    test('round-trips through toMap/fromMap', () {
      final w = Worksheet(
        id: 'w1',
        classroomId: 'c1',
        teacherUid: 't1',
        title: '1단원 쪽지시험',
        description: '범위: 1~10p',
        createdAt: DateTime.parse('2026-06-13T09:00:00.000'),
        updatedAt: DateTime.parse('2026-06-14T10:00:00.000'),
      );
      final back = Worksheet.fromMap(w.toMap());
      expect(back.id, w.id);
      expect(back.classroomId, w.classroomId);
      expect(back.teacherUid, w.teacherUid);
      expect(back.title, w.title);
      expect(back.description, w.description);
      expect(back.createdAt, w.createdAt);
      expect(back.updatedAt, w.updatedAt);
    });

    test('fromMap tolerates missing fields', () {
      final w = Worksheet.fromMap(const {});
      expect(w.id, '');
      expect(w.title, '');
      expect(w.createdAt, isNull);
    });
  });

  group('WorksheetQuestion serialization', () {
    test('round-trips including choices', () {
      final q = WorksheetQuestion(
        id: 'q1',
        worksheetId: 'w1',
        teacherUid: 't1',
        type: WorksheetQuestionType.multipleChoice,
        question: '대한민국의 수도는?',
        choices: const ['서울', '부산', '대구'],
        answer: '서울',
        order: 2,
      );
      final back = WorksheetQuestion.fromMap(q.toMap());
      expect(back.type, WorksheetQuestionType.multipleChoice);
      expect(back.question, q.question);
      expect(back.choices, q.choices);
      expect(back.answer, q.answer);
      expect(back.order, 2);
    });
  });
}
