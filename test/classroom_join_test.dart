import 'package:flutter_test/flutter_test.dart';

import 'package:ocl_study/data/firebase/classroom_repository.dart';
import 'package:ocl_study/domain/classroom/classroom.dart';

void main() {
  test('generateJoinCode — 6자, 헷갈리는 글자(I/O/0/1) 제외', () {
    final allowed = RegExp(r'^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}$');
    for (var i = 0; i < 300; i++) {
      final code = ClassroomRepository.generateJoinCode();
      expect(allowed.hasMatch(code), isTrue, reason: code);
    }
  });

  test('Classroom joinCode toMap/fromMap 왕복', () {
    const cls = Classroom(id: 'c1', teacherUid: 't1', name: '영어 1반', joinCode: 'ABC234');
    final back = Classroom.fromMap(cls.toMap());
    expect(back.joinCode, 'ABC234');
    expect(back.name, '영어 1반');
  });

  test('joinCode 누락 시 빈 문자열', () {
    final back = Classroom.fromMap(const {'id': 'c1', 'teacherUid': 't1'});
    expect(back.joinCode, '');
  });
}
