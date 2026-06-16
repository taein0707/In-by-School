// 가로세로 퍼즐(P4-2) — 로컬 생성(AI 미사용). 단어+뜻을 그리디 알고리즘으로 교차 배치.
import 'dart:math';

/// 교사 입력: 단어 + 뜻(힌트).
class CrosswordWord {
  final String word;
  final String clue;
  const CrosswordWord({required this.word, required this.clue});

  Map<String, dynamic> toMap() => {'word': word, 'clue': clue};
  factory CrosswordWord.fromMap(Map<String, dynamic> m) =>
      CrosswordWord(word: m['word'] as String? ?? '', clue: m['clue'] as String? ?? '');
}

/// 격자에 배치된 단어(번호·위치·방향 포함).
class PlacedWord {
  final String word;
  final String clue;
  final int row;
  final int col;
  final bool horizontal; // true=가로(across), false=세로(down)
  final int number; // 단서 번호

  const PlacedWord({
    required this.word,
    required this.clue,
    required this.row,
    required this.col,
    required this.horizontal,
    this.number = 0,
  });

  List<String> get letters => word.split('');
  int get length => word.length;

  /// i번째 글자가 놓이는 칸 좌표.
  ({int r, int c}) cellAt(int i) => horizontal ? (r: row, c: col + i) : (r: row + i, c: col);

  Map<String, dynamic> toMap() => {
        'word': word,
        'clue': clue,
        'row': row,
        'col': col,
        'horizontal': horizontal,
        'number': number,
      };

  factory PlacedWord.fromMap(Map<String, dynamic> m) => PlacedWord(
        word: m['word'] as String? ?? '',
        clue: m['clue'] as String? ?? '',
        row: (m['row'] as num?)?.toInt() ?? 0,
        col: (m['col'] as num?)?.toInt() ?? 0,
        horizontal: m['horizontal'] as bool? ?? true,
        number: (m['number'] as num?)?.toInt() ?? 0,
      );
}

class CrosswordPuzzle {
  final int rows;
  final int cols;
  final List<PlacedWord> placed;

  const CrosswordPuzzle({this.rows = 0, this.cols = 0, this.placed = const []});

  static String key(int r, int c) => '${r}_$c';

  /// 정답 글자 격자(칸 → 글자). 채워진 칸만 포함.
  Map<String, String> solutionCells() {
    final cells = <String, String>{};
    for (final p in placed) {
      for (var i = 0; i < p.length; i++) {
        final cell = p.cellAt(i);
        cells[key(cell.r, cell.c)] = p.letters[i];
      }
    }
    return cells;
  }

  List<PlacedWord> get across => placed.where((p) => p.horizontal).toList()..sort((a, b) => a.number.compareTo(b.number));
  List<PlacedWord> get down => placed.where((p) => !p.horizontal).toList()..sort((a, b) => a.number.compareTo(b.number));

  Map<String, dynamic> toMap() => {
        'rows': rows,
        'cols': cols,
        'placed': placed.map((p) => p.toMap()).toList(),
      };

  factory CrosswordPuzzle.fromMap(Map<String, dynamic> m) => CrosswordPuzzle(
        rows: (m['rows'] as num?)?.toInt() ?? 0,
        cols: (m['cols'] as num?)?.toInt() ?? 0,
        placed: (m['placed'] as List?)?.map((e) => PlacedWord.fromMap(Map<String, dynamic>.from(e as Map))).toList() ?? const [],
      );
}

/// 그리디 가로세로 배치 알고리즘(로컬, 결정적 옵션 지원).
class CrosswordGenerator {
  CrosswordGenerator._();

  static CrosswordPuzzle generate(List<CrosswordWord> input, {Random? random}) {
    // 유효 단어만(2자 이상), 길이 내림차순 — 긴 단어부터 골격을 잡는다.
    final words = input.where((w) => w.word.trim().length >= 2).map((w) => CrosswordWord(word: w.word.trim(), clue: w.clue.trim())).toList()
      ..sort((a, b) => b.word.length.compareTo(a.word.length));
    if (words.isEmpty) return const CrosswordPuzzle();

    final grid = <String, String>{}; // "r,c" → letter (좌표 음수 가능)
    final placed = <_Place>[];

    String k(int r, int c) => '$r,$c';
    String? at(int r, int c) => grid[k(r, c)];

    void put(_Place p) {
      final ls = p.word.split('');
      for (var i = 0; i < ls.length; i++) {
        final r = p.horizontal ? p.row : p.row + i;
        final c = p.horizontal ? p.col + i : p.col;
        grid[k(r, c)] = ls[i];
      }
      placed.add(p);
    }

    bool canPlace(String word, int row, int col, bool horizontal, {required bool requireCross}) {
      final ls = word.split('');
      final dr = horizontal ? 0 : 1, dc = horizontal ? 1 : 0;
      // 시작 직전/끝 직후 칸은 비어 있어야 한다.
      if (at(row - dr, col - dc) != null) return false;
      if (at(row + dr * ls.length, col + dc * ls.length) != null) return false;
      var crossings = 0;
      for (var i = 0; i < ls.length; i++) {
        final r = row + dr * i, c = col + dc * i;
        final existing = at(r, c);
        if (existing != null) {
          if (existing != ls[i]) return false;
          crossings++;
        } else {
          // 교차하지 않는 칸은 수직 방향 이웃이 비어 있어야 한다(평행 단어 붙음 방지).
          if (horizontal) {
            if (at(r - 1, c) != null || at(r + 1, c) != null) return false;
          } else {
            if (at(r, c - 1) != null || at(r, c + 1) != null) return false;
          }
        }
      }
      if (requireCross && crossings == 0) return false;
      return true;
    }

    // 첫 단어: 가로로 원점 배치.
    put(_Place(words.first.word, words.first.clue, 0, 0, true));

    for (final w in words.skip(1)) {
      final ls = w.word.split('');
      _Place? best;
      // 새 단어의 각 글자가 기존 격자의 같은 글자와 교차하도록 시도.
      outer:
      for (var i = 0; i < ls.length; i++) {
        for (final entry in grid.entries) {
          if (entry.value != ls[i]) continue;
          final parts = entry.key.split(',');
          final gr = int.parse(parts[0]), gc = int.parse(parts[1]);
          // 기존 글자가 가로 단어 위면 새 단어는 세로로, 그 반대도.
          for (final horizontal in [true, false]) {
            final row = horizontal ? gr : gr - i;
            final col = horizontal ? gc - i : gc;
            if (canPlace(w.word, row, col, horizontal, requireCross: true)) {
              best = _Place(w.word, w.clue, row, col, horizontal);
              break outer;
            }
          }
        }
      }
      if (best != null) put(best);
      // 교차 불가한 단어는 건너뛴다(분리 배치 안 함).
    }

    // 좌표 정규화(최소값을 0으로 이동) + 번호 매기기.
    var minR = 0, minC = 0;
    for (final p in placed) {
      minR = min(minR, p.row);
      minC = min(minC, p.col);
    }
    final shifted = [
      for (final p in placed) _Place(p.word, p.clue, p.row - minR, p.col - minC, p.horizontal),
    ];

    var maxR = 0, maxC = 0;
    for (final p in shifted) {
      final endR = p.horizontal ? p.row : p.row + p.word.length - 1;
      final endC = p.horizontal ? p.col + p.word.length - 1 : p.col;
      maxR = max(maxR, endR);
      maxC = max(maxC, endC);
    }

    // 번호: 단어 시작 칸을 행우선 순서로 정렬해 1부터.
    final ordered = [...shifted]..sort((a, b) => a.row != b.row ? a.row.compareTo(b.row) : a.col.compareTo(b.col));
    // 같은 시작 칸(가로·세로 동시 시작)은 같은 번호를 공유.
    final numberByCell = <String, int>{};
    var next = 1;
    final placedWords = <PlacedWord>[];
    for (final p in ordered) {
      final cellKey = CrosswordPuzzle.key(p.row, p.col);
      final number = numberByCell.putIfAbsent(cellKey, () => next++);
      placedWords.add(PlacedWord(word: p.word, clue: p.clue, row: p.row, col: p.col, horizontal: p.horizontal, number: number));
    }

    return CrosswordPuzzle(rows: maxR + 1, cols: maxC + 1, placed: placedWords);
  }
}

class _Place {
  final String word;
  final String clue;
  final int row;
  final int col;
  final bool horizontal;
  const _Place(this.word, this.clue, this.row, this.col, this.horizontal);
}

/// 학생 풀이 채점(정규화: 공백 무시·대소문자 무시).
class CrosswordGrading {
  CrosswordGrading._();

  static String _norm(String s) => s.trim().toLowerCase();

  /// entries: 칸 키("r_c") → 입력 글자.
  static ({int correct, int total, bool solved, double progress}) grade(
      CrosswordPuzzle puzzle, Map<String, String> entries) {
    final solution = puzzle.solutionCells();
    final total = solution.length;
    if (total == 0) return (correct: 0, total: 0, solved: false, progress: 0);
    var correct = 0;
    solution.forEach((cell, letter) {
      final given = entries[cell];
      if (given != null && _norm(given) == _norm(letter)) correct++;
    });
    return (correct: correct, total: total, solved: correct == total, progress: correct / total);
  }
}
