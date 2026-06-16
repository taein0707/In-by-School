import 'package:flutter_test/flutter_test.dart';
import 'package:ocl_study/domain/engagement/roulette.dart';

void main() {
  group('RouletteMode', () {
    test('fromName round-trips and falls back to student', () {
      for (final m in RouletteMode.values) {
        expect(RouletteMode.fromName(m.name), m);
      }
      expect(RouletteMode.fromName(null), RouletteMode.student);
      expect(RouletteMode.fromName('???'), RouletteMode.student);
    });

    test('labels', () {
      expect(RouletteMode.student.label, '학생 추첨');
      expect(RouletteMode.team.label, '모둠 추첨');
      expect(RouletteMode.number.label, '번호 추첨');
    });
  });

  group('RouletteLogic.numberPool', () {
    test('generates 1번..N번', () {
      expect(RouletteLogic.numberPool(3), ['1번', '2번', '3번']);
    });
    test('non-positive yields empty', () {
      expect(RouletteLogic.numberPool(0), isEmpty);
      expect(RouletteLogic.numberPool(-5), isEmpty);
    });
  });

  group('RouletteLogic.candidates', () {
    test('number mode uses the number pool', () {
      expect(RouletteLogic.candidates(RouletteMode.number, numberCount: 2), ['1번', '2번']);
    });
    test('student / team modes use the student list', () {
      expect(RouletteLogic.candidates(RouletteMode.student, students: ['가', '나']), ['가', '나']);
      expect(RouletteLogic.candidates(RouletteMode.team, students: ['가', '나']), ['가', '나']);
    });
  });
}
