import 'package:flutter_test/flutter_test.dart';
import 'package:ocl_study/domain/classroom/classroom.dart';

void main() {
  group('Classroom 직렬화', () {
    test('Classroom toMap/fromMap 왕복', () {
      final cls = Classroom(
        id: 'cls1',
        teacherUid: 't1',
        name: '영어 1반',
        description: '중1 영어',
        createdAt: DateTime(2026, 6, 16, 9),
      );
      final back = Classroom.fromMap(cls.toMap());
      expect(back.id, 'cls1');
      expect(back.teacherUid, 't1');
      expect(back.name, '영어 1반');
      expect(back.description, '중1 영어');
    });

    test('ClassroomMember 왕복 + idFor + role', () {
      final m = ClassroomMember(
        id: ClassroomMember.idFor('cls1', 'u9'),
        classroomId: 'cls1',
        classroomName: '영어 1반',
        userUid: 'u9',
        teacherUid: 't1',
        role: ClassroomRole.teacher,
        joinedAt: DateTime(2026, 6, 16),
      );
      expect(m.id, 'cls1_u9');
      final back = ClassroomMember.fromMap(m.toMap());
      expect(back.classroomId, 'cls1');
      expect(back.userUid, 'u9');
      expect(back.teacherUid, 't1');
      expect(back.role, ClassroomRole.teacher);
      expect(back.classroomName, '영어 1반');
    });

    test('알 수 없는 role 은 student 로 폴백', () {
      expect(ClassroomRole.fromName('weird'), ClassroomRole.student);
      expect(ClassroomRole.fromName(null), ClassroomRole.student);
    });
  });
}
