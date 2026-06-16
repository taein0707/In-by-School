import 'package:flutter_test/flutter_test.dart';

import 'package:ocl_study/domain/lesson/lesson.dart';

void main() {
  test('Lesson toMap/fromMap 왕복 — 슬라이드 5종 보존', () {
    const lesson = Lesson(
      id: 'l1',
      teacherUid: 't1',
      classroomId: 'c1',
      classroomName: '영어 1반',
      title: '식물의 숨은 색',
      slides: [
        LessonSlide(id: 's1', type: LessonSlideType.title, text: '식물의 숨은 색'),
        LessonSlide(id: 's2', type: LessonSlideType.question, text: '어떻게 관찰할까?'),
        LessonSlide(id: 's3', type: LessonSlideType.ideaBoard, text: '떠오르는 단어를 적어보자'),
        LessonSlide(id: 's4', type: LessonSlideType.timer, timerSeconds: 600),
        LessonSlide(
          id: 's5',
          type: LessonSlideType.quiz,
          text: '광합성 장소는?',
          quizKind: QuizKind.multipleChoice,
          choices: ['엽록체', '미토콘드리아', '핵', '리보솜'],
          answer: '엽록체',
        ),
      ],
    );
    final back = Lesson.fromMap(lesson.toMap());
    expect(back.title, '식물의 숨은 색');
    expect(back.slides.length, 5);
    expect(back.slides[3].type, LessonSlideType.timer);
    expect(back.slides[3].timerSeconds, 600);
    expect(back.slides[4].quizKind, QuizKind.multipleChoice);
    expect(back.slides[4].choices, ['엽록체', '미토콘드리아', '핵', '리보솜']);
    expect(back.slides[4].answer, '엽록체');
  });

  test('알 수 없는 enum 이름은 안전한 기본값으로', () {
    expect(LessonSlideType.fromName('???'), LessonSlideType.title);
    expect(QuizKind.fromName(null), QuizKind.multipleChoice);
  });

  test('copyWith — 제목/슬라이드 교체', () {
    const lesson = Lesson(id: 'l1', teacherUid: 't1');
    final updated = lesson.copyWith(title: '새 제목', slides: [
      const LessonSlide(id: 's1', type: LessonSlideType.title),
    ]);
    expect(updated.title, '새 제목');
    expect(updated.slides.length, 1);
    expect(updated.teacherUid, 't1'); // 보존
  });
}
