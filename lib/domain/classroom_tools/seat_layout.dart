// 랜덤 자리 배치(P3-2) — seatLayouts/{classroomId}.
// 교실 학생 목록을 rows×cols 격자에 배치. seats 는 길이 rows*cols 의 이름 배열('' = 빈자리).
import 'dart:math';

class SeatLayout {
  final String id; // = classroomId(교실당 저장 1개)
  final String classroomId;
  final String teacherUid; // 비정규화(보안규칙용)
  final int rows;
  final int cols;
  final List<String> seats; // 길이 rows*cols, '' = 빈자리
  final DateTime? updatedAt;

  const SeatLayout({
    required this.id,
    required this.classroomId,
    required this.teacherUid,
    this.rows = 0,
    this.cols = 0,
    this.seats = const [],
    this.updatedAt,
  });

  int get capacity => rows * cols;

  Map<String, dynamic> toMap() => {
        'id': id,
        'classroomId': classroomId,
        'teacherUid': teacherUid,
        'rows': rows,
        'cols': cols,
        'seats': seats,
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory SeatLayout.fromMap(Map<String, dynamic> m) => SeatLayout(
        id: m['id'] as String? ?? '',
        classroomId: m['classroomId'] as String? ?? '',
        teacherUid: m['teacherUid'] as String? ?? '',
        rows: (m['rows'] as num?)?.toInt() ?? 0,
        cols: (m['cols'] as num?)?.toInt() ?? 0,
        seats: (m['seats'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        updatedAt: (m['updatedAt'] as String?) != null ? DateTime.tryParse(m['updatedAt'] as String) : null,
      );
}

/// 자리 배치 순수 로직(테스트 대상).
class SeatPlanner {
  SeatPlanner._();

  /// 이름들을 rows*cols 격자에 순서대로 채우고 나머지는 ''. 정원 초과분은 버린다.
  /// 반환 리스트는 길이 rows*cols, 인덱스는 row*cols + col, 가변(스왑 가능).
  static List<String> fill(List<String> names, int rows, int cols) {
    final cap = (rows < 0 ? 0 : rows) * (cols < 0 ? 0 : cols);
    final out = List<String>.filled(cap, '', growable: true);
    for (var i = 0; i < names.length && i < cap; i++) {
      out[i] = names[i];
    }
    return out;
  }

  /// 이름을 무작위로 섞어 격자에 배치.
  static List<String> shuffleFill(List<String> names, int rows, int cols, {Random? random}) {
    final copy = [...names]..shuffle(random ?? Random());
    return fill(copy, rows, cols);
  }
}
