// 가로세로 퍼즐 세트/제출(P4-2) — crosswordSets / crosswordSubmissions.
import 'crossword.dart';

class CrosswordSet {
  final String id;
  final String classroomId;
  final String teacherUid;
  final String title;
  final List<CrosswordWord> words; // 교사 입력(단어+뜻)
  final CrosswordPuzzle puzzle; // 생성된 배치(전원 동일)
  final DateTime? createdAt;

  const CrosswordSet({
    required this.id,
    required this.classroomId,
    required this.teacherUid,
    this.title = '',
    this.words = const [],
    this.puzzle = const CrosswordPuzzle(),
    this.createdAt,
  });

  int get placedCount => puzzle.placed.length;

  Map<String, dynamic> toMap() => {
        'id': id,
        'classroomId': classroomId,
        'teacherUid': teacherUid,
        'title': title,
        'words': words.map((w) => w.toMap()).toList(),
        'puzzle': puzzle.toMap(),
        'createdAt': createdAt?.toIso8601String(),
      };

  factory CrosswordSet.fromMap(Map<String, dynamic> m) => CrosswordSet(
        id: m['id'] as String? ?? '',
        classroomId: m['classroomId'] as String? ?? '',
        teacherUid: m['teacherUid'] as String? ?? '',
        title: m['title'] as String? ?? '',
        words: (m['words'] as List?)?.map((e) => CrosswordWord.fromMap(Map<String, dynamic>.from(e as Map))).toList() ?? const [],
        puzzle: m['puzzle'] != null ? CrosswordPuzzle.fromMap(Map<String, dynamic>.from(m['puzzle'] as Map)) : const CrosswordPuzzle(),
        createdAt: (m['createdAt'] as String?) != null ? DateTime.tryParse(m['createdAt'] as String) : null,
      );
}

class CrosswordSubmission {
  final String id; // '{setId}_{studentUid}'
  final String setId;
  final String teacherUid; // 비정규화(교사 조회용)
  final String studentUid;
  final String studentName;
  final Map<String, String> entries; // 칸 키("r_c") → 입력 글자
  final int correct;
  final int total;
  final bool solved;
  final DateTime? updatedAt;

  const CrosswordSubmission({
    required this.id,
    required this.setId,
    required this.teacherUid,
    required this.studentUid,
    this.studentName = '',
    this.entries = const {},
    this.correct = 0,
    this.total = 0,
    this.solved = false,
    this.updatedAt,
  });

  static String idFor(String setId, String studentUid) => '${setId}_$studentUid';
  double get progress => total == 0 ? 0 : correct / total;

  Map<String, dynamic> toMap() => {
        'id': id,
        'setId': setId,
        'teacherUid': teacherUid,
        'studentUid': studentUid,
        'studentName': studentName,
        'entries': entries,
        'correct': correct,
        'total': total,
        'solved': solved,
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory CrosswordSubmission.fromMap(Map<String, dynamic> m) => CrosswordSubmission(
        id: m['id'] as String? ?? '',
        setId: m['setId'] as String? ?? '',
        teacherUid: m['teacherUid'] as String? ?? '',
        studentUid: m['studentUid'] as String? ?? '',
        studentName: m['studentName'] as String? ?? '',
        entries: (m['entries'] as Map?)?.map((k, v) => MapEntry(k.toString(), v?.toString() ?? '')) ?? const {},
        correct: (m['correct'] as num?)?.toInt() ?? 0,
        total: (m['total'] as num?)?.toInt() ?? 0,
        solved: m['solved'] as bool? ?? false,
        updatedAt: (m['updatedAt'] as String?) != null ? DateTime.tryParse(m['updatedAt'] as String) : null,
      );
}
