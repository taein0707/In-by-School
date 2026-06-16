import 'package:flutter_test/flutter_test.dart';

import 'package:ocl_study/domain/lesson/lesson.dart';
import 'package:ocl_study/domain/lesson/lesson_ai.dart';

void main() {
  group('슬라이드 유형(P10)', () {
    test('최소 27종 이상', () {
      expect(LessonSlideType.values.length, greaterThanOrEqualTo(27));
    });

    test('필드 플래그/카테고리', () {
      expect(LessonSlideType.image.hasMedia, isTrue);
      expect(LessonSlideType.image.category, SlideCategory.info);
      expect(LessonSlideType.multipleChoice.hasChoices, isTrue);
      expect(LessonSlideType.bingo.hasNumber, isTrue);
      expect(LessonSlideType.title.hasMedia, isFalse);
      expect(LessonSlideType.ideaBoard.category, SlideCategory.live);
    });

    test('새 필드(mediaUrl/number) 직렬화 왕복', () {
      const s = LessonSlide(id: 's1', type: LessonSlideType.image, mediaUrl: 'https://x/y.png', number: 5);
      final back = LessonSlide.fromMap(s.toMap());
      expect(back.type, LessonSlideType.image);
      expect(back.mediaUrl, 'https://x/y.png');
      expect(back.number, 5);
    });
  });

  group('LessonAi.heuristic (오프라인 폴백)', () {
    test('제목으로 시작 + 요청 페이지 수 + 요청 유형 사용', () {
      final slides = LessonAi.heuristic(
        topic: '광합성',
        types: [LessonSlideType.question, LessonSlideType.quiz],
        pageCount: 5,
      );
      expect(slides.length, 5);
      expect(slides.first.type, LessonSlideType.title);
      expect(slides.first.text.contains('광합성'), isTrue);
      expect(slides.skip(1).every((s) => s.type == LessonSlideType.question || s.type == LessonSlideType.quiz), isTrue);
    });

    test('유형 미지정이면 기본 골격', () {
      final slides = LessonAi.heuristic(topic: '', types: const [], pageCount: 3);
      expect(slides.length, 3);
      expect(slides.first.type, LessonSlideType.title);
    });
  });

  group('LessonAi.parseSlides (AI 응답 파싱)', () {
    test('slides JSON → LessonSlide, 알 수 없는 type 은 title 로', () {
      final json = {
        'slides': [
          {'type': 'title', 'text': '광합성 알아보기'},
          {'type': 'multipleChoice', 'text': '문제', 'choices': ['A', 'B'], 'answer': 'A'},
          {'type': 'timer', 'timerSeconds': 300},
          {'type': '존재안함', 'text': '폴백'},
        ]
      };
      final slides = LessonAi.parseSlides(json);
      expect(slides.length, 4);
      expect(slides[0].text, '광합성 알아보기');
      expect(slides[1].type, LessonSlideType.multipleChoice);
      expect(slides[1].choices, ['A', 'B']);
      expect(slides[1].answer, 'A');
      expect(slides[3].type, LessonSlideType.title); // 폴백
    });

    test('slides 없으면 빈 리스트', () {
      expect(LessonAi.parseSlides({'foo': 1}), isEmpty);
      expect(LessonAi.parseSlides('nope'), isEmpty);
    });
  });
}
