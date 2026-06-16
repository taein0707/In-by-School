import 'package:flutter_test/flutter_test.dart';
import 'package:ocl_study/domain/report/study_report_template.dart';
import 'package:ocl_study/domain/report/study_report.dart';

void main() {
  group('StudyReportTemplate.compose — 로컬 초안 생성', () {
    test('데이터가 없으면 계획 점검 문구', () {
      final text = StudyReportTemplate.compose(const StudySummary());
      expect(text, contains('학습 계획을 점검'));
      expect(text, contains('내일'));
    });

    test('복습·시간을 반영한다', () {
      const s = StudySummary(
        studyMinutes: 42,
        subjects: ['영어'],
        reviewedCards: 18,
        sessionCount: 2,
      );
      final text = StudyReportTemplate.compose(s);
      expect(text, contains('영어'));
      expect(text, contains('총 42분'));
      expect(text, contains('복습 카드 18장'));
      expect(text, contains('내일'));
    });

    test('낮은 정답률이면 오답 보완 문구', () {
      const s = StudySummary(studyMinutes: 30, subjects: ['수학'], quizAccuracy: 55);
      final text = StudyReportTemplate.compose(s);
      expect(text, contains('정답률은 55%'));
      expect(text, contains('오답'));
    });

    test('여러 과목은 ·로 묶는다', () {
      const s = StudySummary(studyMinutes: 20, subjects: ['영어', '수학'], reviewedCards: 3);
      final text = StudyReportTemplate.compose(s);
      expect(text, contains('영어·수학'));
    });
  });

  group('StudyReport 직렬화', () {
    test('toMap/fromMap 왕복', () {
      final r = StudyReport(
        id: 'r1',
        studentUid: 'stu',
        teacherUid: 'tea',
        studentName: '민수',
        subject: '영어',
        studyMinutes: 42,
        content: '오늘은 영어를 공부하였다.',
        status: ReportStatus.submitted,
        submittedAt: DateTime(2026, 6, 13, 21),
        createdAt: DateTime(2026, 6, 13, 20),
        updatedAt: DateTime(2026, 6, 13, 21),
      );
      final back = StudyReport.fromMap(r.toMap());
      expect(back.id, 'r1');
      expect(back.teacherUid, 'tea');
      expect(back.studyMinutes, 42);
      expect(back.isSubmitted, isTrue);
      expect(back.content, contains('영어'));
    });
  });
}
