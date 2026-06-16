import 'package:flutter_test/flutter_test.dart';
import 'package:ocl_study/domain/announcement/announcement.dart';

void main() {
  group('Announcement 직렬화/타입', () {
    test('toMap/fromMap 왕복', () {
      final a = Announcement(
        id: 'a1',
        classroomId: 'cls1',
        teacherUid: 't1',
        title: '수행평가 일정 안내',
        content: '6월 28일까지 제출',
        type: AnnouncementType.exam,
        createdAt: DateTime(2026, 6, 16, 9),
        updatedAt: DateTime(2026, 6, 16, 9),
      );
      final back = Announcement.fromMap(a.toMap());
      expect(back.id, 'a1');
      expect(back.classroomId, 'cls1');
      expect(back.teacherUid, 't1');
      expect(back.title, '수행평가 일정 안내');
      expect(back.type, AnnouncementType.exam);
    });

    test('타입 라벨', () {
      expect(AnnouncementType.notice.label, '공지');
      expect(AnnouncementType.assignment.label, '숙제');
      expect(AnnouncementType.exam.label, '수행평가');
      expect(AnnouncementType.event.label, '일정');
    });

    test('알 수 없는 타입은 notice 폴백', () {
      expect(AnnouncementType.fromName('xyz'), AnnouncementType.notice);
      expect(AnnouncementType.fromName(null), AnnouncementType.notice);
    });
  });
}
