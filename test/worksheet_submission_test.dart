import 'package:flutter_test/flutter_test.dart';
import 'package:ocl_study/domain/worksheet/worksheet_submission.dart';

void main() {
  group('WorksheetSubmission.idFor', () {
    test('combines worksheetId and studentUid deterministically', () {
      expect(WorksheetSubmission.idFor('w1', 's1'), 'w1_s1');
      expect(WorksheetSubmission.idFor('w1', 's1'), WorksheetSubmission.idFor('w1', 's1'));
      expect(WorksheetSubmission.idFor('w1', 's1'), isNot(WorksheetSubmission.idFor('w1', 's2')));
    });
  });

  group('WorksheetSubmission serialization', () {
    test('round-trips through toMap/fromMap', () {
      final s = WorksheetSubmission(
        id: 'w1_s1',
        worksheetId: 'w1',
        teacherUid: 't1',
        studentUid: 's1',
        studentName: '홍길동',
        answers: const {'q1': '서울', 'q2': 'apple'},
        score: 2,
        total: 3,
        submittedAt: DateTime.parse('2026-06-13T09:30:00.000'),
      );
      final back = WorksheetSubmission.fromMap(s.toMap());
      expect(back.id, s.id);
      expect(back.worksheetId, s.worksheetId);
      expect(back.teacherUid, s.teacherUid);
      expect(back.studentUid, s.studentUid);
      expect(back.studentName, s.studentName);
      expect(back.answers, s.answers);
      expect(back.score, 2);
      expect(back.total, 3);
      expect(back.submittedAt, s.submittedAt);
    });

    test('fromMap tolerates missing fields and null submittedAt', () {
      final s = WorksheetSubmission.fromMap(const {});
      expect(s.id, '');
      expect(s.answers, isEmpty);
      expect(s.score, 0);
      expect(s.total, 0);
      expect(s.submittedAt, isNull);
    });

    test('answers coerce non-string values to strings', () {
      final s = WorksheetSubmission.fromMap({
        'id': 'x',
        'answers': {'q1': 1, 'q2': true},
      });
      expect(s.answers['q1'], '1');
      expect(s.answers['q2'], 'true');
    });
  });
}
