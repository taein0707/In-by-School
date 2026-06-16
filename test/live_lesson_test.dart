import 'package:flutter_test/flutter_test.dart';

import 'package:ocl_study/domain/lesson/live.dart';

void main() {
  group('직렬화', () {
    test('LessonSession toMap/fromMap 왕복', () {
      const s = LessonSession(
        lessonId: 'l1',
        teacherUid: 't1',
        classroomId: 'c1',
        currentSlide: 3,
        live: true,
        paused: true,
        allowFreeMove: true,
      );
      final back = LessonSession.fromMap(s.toMap());
      expect(back.currentSlide, 3);
      expect(back.live, isTrue);
      expect(back.paused, isTrue);
      expect(back.allowFreeMove, isTrue);
      expect(back.classroomId, 'c1');
    });

    test('LessonPointer toMap/fromMap 왕복 (P10-3)', () {
      const p = LessonPointer(lessonId: 'l1', teacherUid: 't1', x: 0.3, y: 0.7, color: 'red', active: true);
      final back = LessonPointer.fromMap(p.toMap());
      expect(back.x, 0.3);
      expect(back.y, 0.7);
      expect(back.color, 'red');
      expect(back.active, isTrue);
    });

    test('LessonQuestion toMap/fromMap 왕복 (P10-3)', () {
      const q = LessonQuestion(
        id: 'q1',
        lessonId: 'l1',
        teacherUid: 't1',
        studentUid: 'u1',
        text: '이해가 안돼요',
        approved: false,
        anonymous: true,
      );
      final back = LessonQuestion.fromMap(q.toMap());
      expect(back.text, '이해가 안돼요');
      expect(back.approved, isFalse);
      expect(back.anonymous, isTrue);
    });

    test('LessonResponse toMap/fromMap 왕복', () {
      const r = LessonResponse(
        id: 'r1',
        lessonId: 'l1',
        slideId: 's1',
        studentUid: 'u1',
        teacherUid: 't1',
        studentName: '김철수',
        kind: ResponseKind.idea,
        text: '자유',
      );
      final back = LessonResponse.fromMap(r.toMap());
      expect(back.kind, ResponseKind.idea);
      expect(back.text, '자유');
      expect(back.studentName, '김철수');
    });
  });

  group('아이디어/반응 직렬화 (P10-4)', () {
    test('LessonIdea toMap/fromMap 왕복', () {
      const i = LessonIdea(
        id: 'i1', lessonId: 'l1', slideId: 's1', teacherUid: 't1', authorUid: 'u1', authorName: '김철수',
        text: '자유', color: 'pink', groupId: 'g1', x: 0.3, y: 0.7, scale: 1.4, rotation: 0.1, locked: true, zIndex: 5,
      );
      final back = LessonIdea.fromMap(i.toMap());
      expect(back.text, '자유');
      expect(back.color, 'pink');
      expect(back.x, 0.3);
      expect(back.scale, 1.4);
      expect(back.locked, isTrue);
      expect(back.groupId, 'g1');
    });

    test('LessonReaction toMap/fromMap 왕복', () {
      const r = LessonReaction(id: 'r1', lessonId: 'l1', targetId: 'i1', emoji: '👍', studentUid: 'u1');
      final back = LessonReaction.fromMap(r.toMap());
      expect(back.emoji, '👍');
      expect(back.targetId, 'i1');
    });

    test('reactionCounts — 대상별 emoji 집계', () {
      const list = [
        LessonReaction(id: 'a', lessonId: 'l', targetId: 'i1', emoji: '👍', studentUid: 'u1'),
        LessonReaction(id: 'b', lessonId: 'l', targetId: 'i1', emoji: '👍', studentUid: 'u2'),
        LessonReaction(id: 'c', lessonId: 'l', targetId: 'i1', emoji: '❤️', studentUid: 'u3'),
        LessonReaction(id: 'd', lessonId: 'l', targetId: 'i2', emoji: '⭐', studentUid: 'u1'),
      ];
      final counts = LiveAggregate.reactionCounts(list);
      expect(counts['i1']!['👍'], 2);
      expect(counts['i1']!['❤️'], 1);
      expect(counts['i2']!['⭐'], 1);
    });
  });

  group('LiveAggregate', () {
    test('tally — 제출 빈도(대소문자 통합)', () {
      final counts = LiveAggregate.tally(['자유', '권리', '권리', '평등', ' 권리 ', 'Freedom', 'freedom']);
      expect(counts['권리'], 3);
      expect(counts['자유'], 1);
      expect(counts['평등'], 1);
      expect(counts['Freedom'], 2); // 대소문자 통합, 표시는 첫 등장형
    });

    test('top — 빈도 내림차순', () {
      final top = LiveAggregate.top(LiveAggregate.tally(['a', 'b', 'b', 'c', 'c', 'c']));
      expect(top.first.key, 'c');
      expect(top.first.value, 3);
      expect(top[1].key, 'b');
    });

    test('heuristicSummary — 상위 키워드 / 빈 입력', () {
      final s = LiveAggregate.heuristicSummary(['자유', '권리', '권리', '평등']);
      expect(s.contains('권리'), isTrue);
      expect(LiveAggregate.heuristicSummary(const []), '아직 모인 답변이 없어요.');
    });
  });
}
