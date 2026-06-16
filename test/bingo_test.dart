import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:ocl_study/domain/engagement/bingo_game.dart';

void main() {
  group('BingoLogic.generateBoard', () {
    test('produces exactly size*size cells from the pool', () {
      final board = BingoLogic.generateBoard(['a', 'b', 'c', 'd', 'e'], 2, random: Random(1));
      expect(board.length, 4);
      expect(board.toSet().difference({'a', 'b', 'c', 'd', 'e'}), isEmpty);
    });

    test('pads with empty cells when the pool is too small', () {
      final board = BingoLogic.generateBoard(['a', 'b'], 2, random: Random(1));
      expect(board.length, 4);
      expect(board.where((w) => w.isEmpty).length, 2);
    });

    test('deterministic for a fixed seed', () {
      final a = BingoLogic.generateBoard(['a', 'b', 'c', 'd'], 2, random: Random(5));
      final b = BingoLogic.generateBoard(['a', 'b', 'c', 'd'], 2, random: Random(5));
      expect(a, b);
    });
  });

  group('BingoLogic.isBoardComplete', () {
    test('true only when every non-empty cell is called', () {
      final board = ['a', 'b', 'c', 'd'];
      expect(BingoLogic.isBoardComplete(board, ['a', 'b', 'c']), isFalse);
      expect(BingoLogic.isBoardComplete(board, ['a', 'b', 'c', 'd']), isTrue);
    });

    test('ignores empty cells', () {
      final board = ['a', '', 'c', ''];
      expect(BingoLogic.isBoardComplete(board, ['a', 'c']), isTrue);
    });

    test('all-empty board is never complete', () {
      expect(BingoLogic.isBoardComplete(['', '', '', ''], ['x']), isFalse);
    });
  });

  group('BingoLogic.markedCount', () {
    test('counts called non-empty cells', () {
      expect(BingoLogic.markedCount(['a', 'b', '', 'd'], ['a', 'd', 'z']), 2);
    });
  });

  group('BingoLogic.nextTurn', () {
    test('cycles through the order', () {
      final order = ['u1', 'u2', 'u3'];
      expect(BingoLogic.nextTurn(order, 'u1'), 'u2');
      expect(BingoLogic.nextTurn(order, 'u3'), 'u1'); // wraps
    });

    test('unknown current falls back to first', () {
      expect(BingoLogic.nextTurn(['u1', 'u2'], 'zzz'), 'u1');
    });

    test('empty order yields empty', () {
      expect(BingoLogic.nextTurn(const [], 'u1'), '');
    });
  });

  group('BingoGame serialization', () {
    test('round-trips including boards and names', () {
      final g = BingoGame(
        id: 'g1',
        classroomId: 'c1',
        teacherUid: 't1',
        title: '영단어',
        size: 2,
        mode: BingoMode.team,
        words: const ['a', 'b', 'c', 'd'],
        turnOrder: const ['u1', 'u2'],
        currentTurn: 'u1',
        calledWords: const ['a'],
        completedUsers: const [],
        winner: '',
        status: BingoStatus.playing,
        boards: const {
          'u1': ['a', 'b', 'c', 'd'],
          'u2': ['d', 'c', 'b', 'a'],
        },
        names: const {'u1': '가', 'u2': '나'},
        createdAt: DateTime.parse('2026-06-13T09:00:00.000'),
      );
      final back = BingoGame.fromMap(g.toMap());
      expect(back.mode, BingoMode.team);
      expect(back.status, BingoStatus.playing);
      expect(back.boards['u1'], ['a', 'b', 'c', 'd']);
      expect(back.boards['u2'], ['d', 'c', 'b', 'a']);
      expect(back.names['u2'], '나');
      expect(back.calledWords, ['a']);
      expect(back.boardOf('u1'), ['a', 'b', 'c', 'd']);
    });

    test('fromMap tolerates missing fields with sane defaults', () {
      final g = BingoGame.fromMap(const {});
      expect(g.size, 3);
      expect(g.mode, BingoMode.individual);
      expect(g.status, BingoStatus.waiting);
      expect(g.boards, isEmpty);
      expect(g.isFinished, isFalse);
    });
  });
}
