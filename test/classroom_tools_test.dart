import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:ocl_study/domain/classroom_tools/group_activity.dart';
import 'package:ocl_study/domain/classroom_tools/seat_layout.dart';

void main() {
  group('SeatPlanner.fill', () {
    test('places names in order and pads empties to capacity', () {
      final seats = SeatPlanner.fill(['A', 'B', 'C'], 2, 3);
      expect(seats.length, 6);
      expect(seats.sublist(0, 3), ['A', 'B', 'C']);
      expect(seats.sublist(3), ['', '', '']);
    });

    test('drops names beyond capacity', () {
      final seats = SeatPlanner.fill(['A', 'B', 'C', 'D', 'E'], 2, 2);
      expect(seats.length, 4);
      expect(seats, ['A', 'B', 'C', 'D']);
    });

    test('zero / negative dimensions yield empty', () {
      expect(SeatPlanner.fill(['A'], 0, 5), isEmpty);
      expect(SeatPlanner.fill(['A'], 3, 0), isEmpty);
      expect(SeatPlanner.fill(['A'], -1, 4), isEmpty);
    });

    test('returned list is mutable (supports manual swap)', () {
      final seats = SeatPlanner.fill(['A', 'B'], 1, 2);
      final tmp = seats[0];
      seats[0] = seats[1];
      seats[1] = tmp;
      expect(seats, ['B', 'A']);
    });
  });

  group('SeatPlanner.shuffleFill', () {
    test('preserves the multiset of names within capacity', () {
      final names = ['A', 'B', 'C', 'D'];
      final seats = SeatPlanner.shuffleFill(names, 2, 2, random: Random(7));
      expect(seats.length, 4);
      expect(seats.toSet(), names.toSet());
    });

    test('deterministic for a fixed seed', () {
      final a = SeatPlanner.shuffleFill(['A', 'B', 'C', 'D'], 2, 2, random: Random(42));
      final b = SeatPlanner.shuffleFill(['A', 'B', 'C', 'D'], 2, 2, random: Random(42));
      expect(a, b);
    });
  });

  group('SeatLayout serialization', () {
    test('round-trips through toMap/fromMap', () {
      final layout = SeatLayout(
        id: 'c1',
        classroomId: 'c1',
        teacherUid: 't1',
        rows: 2,
        cols: 3,
        seats: const ['A', 'B', '', 'C', '', ''],
        updatedAt: DateTime.parse('2026-06-13T09:00:00.000'),
      );
      final back = SeatLayout.fromMap(layout.toMap());
      expect(back.classroomId, 'c1');
      expect(back.rows, 2);
      expect(back.cols, 3);
      expect(back.capacity, 6);
      expect(back.seats, layout.seats);
      expect(back.updatedAt, layout.updatedAt);
    });
  });

  group('GroupMaker.chunk', () {
    test('splits in order with a smaller final group', () {
      final g = GroupMaker.chunk(['A', 'B', 'C', 'D', 'E'], 2);
      expect(g, [
        ['A', 'B'],
        ['C', 'D'],
        ['E'],
      ]);
    });

    test('all members are present exactly once', () {
      final students = List.generate(10, (i) => 'S$i');
      final g = GroupMaker.chunk(students, 3);
      expect(g.expand((x) => x).toList(), students);
      expect(g.length, 4); // 3+3+3+1
    });

    test('size < 1 is treated as 1', () {
      final g = GroupMaker.chunk(['A', 'B'], 0);
      expect(g, [
        ['A'],
        ['B'],
      ]);
    });

    test('empty students yields no groups', () {
      expect(GroupMaker.chunk(const [], 3), isEmpty);
    });
  });

  group('GroupMaker.make', () {
    test('keeps every student and respects group size', () {
      final students = List.generate(7, (i) => 'S$i');
      final g = GroupMaker.make(students, 3, random: Random(1));
      expect(g.expand((x) => x).toSet(), students.toSet());
      expect(g.expand((x) => x).length, 7);
      expect(g.first.length, 3);
    });
  });

  group('PresenterPicker.available', () {
    test('allowRepeat returns the full list', () {
      final a = PresenterPicker.available(['A', 'B', 'C'], ['A'], true);
      expect(a, ['A', 'B', 'C']);
    });

    test('no-repeat excludes recent picks', () {
      final a = PresenterPicker.available(['A', 'B', 'C'], ['A', 'B'], false);
      expect(a, ['C']);
    });

    test('no-repeat resets to full list when everyone has presented', () {
      final a = PresenterPicker.available(['A', 'B'], ['A', 'B'], false);
      expect(a.toSet(), {'A', 'B'});
    });
  });

  group('PresenterPicker.pick', () {
    test('returns null for empty roster', () {
      expect(PresenterPicker.pick(const []), isNull);
    });

    test('no-repeat picks the only remaining candidate', () {
      final p = PresenterPicker.pick(['A', 'B', 'C'], recent: ['A', 'B'], allowRepeat: false, random: Random(3));
      expect(p, 'C');
    });

    test('always returns someone from the roster', () {
      final p = PresenterPicker.pick(['A', 'B', 'C'], random: Random(9));
      expect(['A', 'B', 'C'], contains(p));
    });
  });

  group('GroupActivity serialization', () {
    test('round-trips groups via nested-array encoding', () {
      final a = GroupActivity(
        id: 'g1',
        classroomId: 'c1',
        teacherUid: 't1',
        type: GroupActivityType.groups,
        groupSize: 2,
        groups: const [
          ['A', 'B'],
          ['C'],
        ],
        createdAt: DateTime.parse('2026-06-13T09:00:00.000'),
      );
      final map = a.toMap();
      expect(map['groups'], [
        {'members': ['A', 'B']},
        {'members': ['C']},
      ]);
      final back = GroupActivity.fromMap(map);
      expect(back.type, GroupActivityType.groups);
      expect(back.groupSize, 2);
      expect(back.groups, a.groups);
    });

    test('round-trips presenter picks', () {
      final a = GroupActivity(
        id: 'g2',
        classroomId: 'c1',
        teacherUid: 't1',
        type: GroupActivityType.presenter,
        picks: const ['B', 'A'],
        createdAt: DateTime.parse('2026-06-14T09:00:00.000'),
      );
      final back = GroupActivity.fromMap(a.toMap());
      expect(back.type, GroupActivityType.presenter);
      expect(back.picks, ['B', 'A']);
      expect(back.groups, isEmpty);
    });

    test('fromMap tolerates missing fields', () {
      final a = GroupActivity.fromMap(const {});
      expect(a.type, GroupActivityType.groups);
      expect(a.groups, isEmpty);
      expect(a.picks, isEmpty);
      expect(a.createdAt, isNull);
    });
  });
}
