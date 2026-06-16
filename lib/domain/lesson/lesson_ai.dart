import 'lesson.dart';

/// AI 자동 수업 생성의 순수 로직(P10) — 네트워크 무의존, 단위 테스트 가능.
class LessonAi {
  LessonAi._();

  /// AI 응답 JSON(`{slides:[{type,text,choices,answer,number,mediaUrl}]}` 또는 슬라이드 배열)
  /// → [LessonSlide] 목록. 알 수 없는 type 은 title 로 흡수한다.
  static List<LessonSlide> parseSlides(dynamic json) {
    final list = (json is Map ? json['slides'] : json);
    if (list is! List) return const [];
    final out = <LessonSlide>[];
    for (var i = 0; i < list.length; i++) {
      final e = list[i];
      if (e is! Map) continue;
      final m = e.cast<String, dynamic>();
      final text = ((m['text'] ?? m['title'] ?? '') as Object).toString().trim();
      out.add(LessonSlide(
        id: 'g$i',
        type: LessonSlideType.fromName(m['type'] as String?),
        text: text,
        mediaUrl: ((m['mediaUrl'] ?? '') as Object).toString().trim(),
        number: (m['number'] as num?)?.toInt() ?? 0,
        timerSeconds: (m['timerSeconds'] as num?)?.toInt() ?? 300,
        quizKind: QuizKind.fromName(m['quizKind'] as String?),
        choices: (m['choices'] as List?)?.map((c) => c.toString()).toList() ?? const [],
        answer: ((m['answer'] ?? '') as Object).toString().trim(),
      ));
    }
    return out;
  }

  /// 오프라인 폴백 — 주제 + 요청 유형으로 결정적 골격 슬라이드를 만든다.
  /// 항상 제목 슬라이드로 시작하고, 요청 유형을 순환하며 [pageCount] 개를 채운다.
  static List<LessonSlide> heuristic({
    required String topic,
    required List<LessonSlideType> types,
    required int pageCount,
  }) {
    final t = topic.trim().isEmpty ? '오늘의 주제' : topic.trim();
    final n = pageCount.clamp(1, 50);
    final pool = types.isEmpty
        ? const [LessonSlideType.description, LessonSlideType.question, LessonSlideType.quiz, LessonSlideType.exitTicket]
        : types;
    final out = <LessonSlide>[LessonSlide(id: 'h0', type: LessonSlideType.title, text: '$t 알아보기')];
    var i = 1;
    while (out.length < n) {
      out.add(_skeleton('h$i', pool[(i - 1) % pool.length], t));
      i++;
    }
    return out;
  }

  static LessonSlide _skeleton(String id, LessonSlideType type, String topic) {
    switch (type) {
      case LessonSlideType.quiz:
      case LessonSlideType.quizBattle:
      case LessonSlideType.multipleChoice:
        return LessonSlide(id: id, type: type, text: '$topic 관련 문제', choices: const ['보기 1', '보기 2', '보기 3', '보기 4']);
      case LessonSlideType.ox:
        return LessonSlide(id: id, type: type, text: '$topic 에 대한 설명이다.', choices: const ['O', 'X'], answer: 'O');
      case LessonSlideType.timer:
        return LessonSlide(id: id, type: type, text: '생각할 시간', timerSeconds: 300);
      case LessonSlideType.ideaBoard:
        return LessonSlide(id: id, type: type, text: '$topic 하면 떠오르는 것을 자유롭게 적어보자');
      case LessonSlideType.exitTicket:
        return LessonSlide(id: id, type: type, text: '오늘 새롭게 알게 된 것은?');
      case LessonSlideType.description:
        return LessonSlide(id: id, type: type, text: '$topic 의 핵심 개념');
      case LessonSlideType.question:
        return LessonSlide(id: id, type: type, text: '$topic 에 대해 어떻게 생각하나요?');
      default:
        return LessonSlide(id: id, type: type, text: '$topic — ${type.label}');
    }
  }
}
