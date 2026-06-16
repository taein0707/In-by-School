import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:ocl_study/domain/engagement/crossword.dart';
import 'package:ocl_study/domain/engagement/crossword_set.dart';

void main() {
  group('CrosswordGenerator.generate', () {
    test('empty / too-short input yields empty puzzle', () {
      expect(CrosswordGenerator.generate(const []).placed, isEmpty);
      expect(CrosswordGenerator.generate([const CrosswordWord(word: 'a', clue: '')]).placed, isEmpty);
    });

    test('single valid word is placed horizontally at origin', () {
      final p = CrosswordGenerator.generate([const CrosswordWord(word: 'apple', clue: '사과')]);
      expect(p.placed.length, 1);
      expect(p.placed.first.horizontal, isTrue);
      expect(p.placed.first.row, 0);
      expect(p.placed.first.col, 0);
      expect(p.rows, 1);
      expect(p.cols, 5);
    });

    test('intersecting words share a consistent letter on the grid', () {
      final p = CrosswordGenerator.generate([
        const CrosswordWord(word: 'apple', clue: '사과'),
        const CrosswordWord(word: 'pear', clue: '배'), // shares 'p'/'a'/'e' with apple
        const CrosswordWord(word: 'plum', clue: '자두'),
      ], random: Random(1));
      // 최소 2개는 연결되어 배치된다.
      expect(p.placed.length, greaterThanOrEqualTo(2));
      // 격자 위 모든 칸이 단일 글자로 일관(교차 충돌 없음).
      final cells = <String, String>{};
      for (final w in p.placed) {
        for (var i = 0; i < w.length; i++) {
          final cell = w.cellAt(i);
          final key = CrosswordPuzzle.key(cell.r, cell.c);
          if (cells.containsKey(key)) {
            expect(cells[key], w.letters[i], reason: 'intersection mismatch at $key');
          } else {
            cells[key] = w.letters[i];
          }
        }
      }
    });

    test('coordinates are normalised to non-negative within bounds', () {
      final p = CrosswordGenerator.generate([
        const CrosswordWord(word: 'apple', clue: ''),
        const CrosswordWord(word: 'maple', clue: ''),
        const CrosswordWord(word: 'lamp', clue: ''),
      ], random: Random(3));
      for (final w in p.placed) {
        expect(w.row, greaterThanOrEqualTo(0));
        expect(w.col, greaterThanOrEqualTo(0));
        final endR = w.horizontal ? w.row : w.row + w.length - 1;
        final endC = w.horizontal ? w.col + w.length - 1 : w.col;
        expect(endR, lessThan(p.rows));
        expect(endC, lessThan(p.cols));
      }
    });

    test('clue numbers are assigned and a shared start cell shares a number', () {
      final p = CrosswordGenerator.generate([
        const CrosswordWord(word: 'apple', clue: ''),
        const CrosswordWord(word: 'ant', clue: ''),
      ], random: Random(2));
      for (final w in p.placed) {
        expect(w.number, greaterThanOrEqualTo(1));
      }
    });
  });

  group('CrosswordPuzzle', () {
    test('solutionCells maps every letter cell', () {
      final p = CrosswordGenerator.generate([const CrosswordWord(word: 'cat', clue: '')]);
      final cells = p.solutionCells();
      expect(cells.length, 3);
      expect(cells[CrosswordPuzzle.key(0, 0)], 'c');
      expect(cells[CrosswordPuzzle.key(0, 2)], 't');
    });

    test('serialization round-trips', () {
      final p = CrosswordGenerator.generate([
        const CrosswordWord(word: 'apple', clue: '사과'),
        const CrosswordWord(word: 'pear', clue: '배'),
      ], random: Random(1));
      final back = CrosswordPuzzle.fromMap(p.toMap());
      expect(back.rows, p.rows);
      expect(back.cols, p.cols);
      expect(back.placed.length, p.placed.length);
      expect(back.placed.first.word, p.placed.first.word);
    });
  });

  group('CrosswordGrading.grade', () {
    final puzzle = CrosswordGenerator.generate([const CrosswordWord(word: 'cat', clue: '')]);

    test('all-correct entries solve the puzzle', () {
      final entries = {
        CrosswordPuzzle.key(0, 0): 'c',
        CrosswordPuzzle.key(0, 1): 'a',
        CrosswordPuzzle.key(0, 2): 't',
      };
      final g = CrosswordGrading.grade(puzzle, entries);
      expect(g.total, 3);
      expect(g.correct, 3);
      expect(g.solved, isTrue);
      expect(g.progress, 1.0);
    });

    test('case-insensitive and partial', () {
      final g = CrosswordGrading.grade(puzzle, {
        CrosswordPuzzle.key(0, 0): 'C',
        CrosswordPuzzle.key(0, 1): 'x',
      });
      expect(g.correct, 1);
      expect(g.solved, isFalse);
    });

    test('empty puzzle grades to zero', () {
      final g = CrosswordGrading.grade(const CrosswordPuzzle(), const {});
      expect(g.total, 0);
      expect(g.solved, isFalse);
      expect(g.progress, 0);
    });
  });

  group('CrosswordSet / CrosswordSubmission serialization', () {
    test('set round-trips with generated puzzle', () {
      final puzzle = CrosswordGenerator.generate([const CrosswordWord(word: 'cat', clue: '고양이')]);
      final set = CrosswordSet(
        id: 's1',
        classroomId: 'c1',
        teacherUid: 't1',
        title: '동물',
        words: const [CrosswordWord(word: 'cat', clue: '고양이')],
        puzzle: puzzle,
        createdAt: DateTime.parse('2026-06-13T09:00:00.000'),
      );
      final back = CrosswordSet.fromMap(set.toMap());
      expect(back.title, '동물');
      expect(back.words.first.clue, '고양이');
      expect(back.puzzle.placed.length, 1);
      expect(back.placedCount, 1);
    });

    test('submission round-trips and idFor is deterministic', () {
      expect(CrosswordSubmission.idFor('s1', 'u1'), 's1_u1');
      final sub = CrosswordSubmission(
        id: 's1_u1',
        setId: 's1',
        teacherUid: 't1',
        studentUid: 'u1',
        studentName: '가',
        entries: const {'0_0': 'c'},
        correct: 1,
        total: 3,
        solved: false,
        updatedAt: DateTime.parse('2026-06-13T10:00:00.000'),
      );
      final back = CrosswordSubmission.fromMap(sub.toMap());
      expect(back.entries['0_0'], 'c');
      expect(back.correct, 1);
      expect(back.total, 3);
      expect(back.progress, closeTo(1 / 3, 1e-9));
    });
  });
}
