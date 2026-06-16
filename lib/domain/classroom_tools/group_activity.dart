// 모둠 만들기 / 발표 학생 추첨(P3-2) — groupActivities/{id}.
// 한 컬렉션으로 모둠 결과(groups)와 발표 추첨 기록(picks)을 함께 보관.
import 'dart:math';

enum GroupActivityType {
  groups, // 모둠 만들기
  presenter, // 발표 학생 추첨
  roulette; // 랜덤 룰렛(학생/모둠/번호) — P4-4

  static GroupActivityType fromName(String? s) =>
      values.firstWhere((e) => e.name == s, orElse: () => GroupActivityType.groups);

  String get label => switch (this) {
        GroupActivityType.groups => '모둠',
        GroupActivityType.presenter => '발표 추첨',
        GroupActivityType.roulette => '룰렛',
      };
}

class GroupActivity {
  final String id;
  final String classroomId;
  final String teacherUid; // 비정규화(보안규칙용)
  final GroupActivityType type;
  final int groupSize; // 모둠: 모둠당 인원
  final List<List<String>> groups; // 모둠 결과(Firestore: [{members:[...]}])
  final List<String> picks; // 발표 추첨 기록(최근순)
  final DateTime? createdAt;

  const GroupActivity({
    required this.id,
    required this.classroomId,
    required this.teacherUid,
    this.type = GroupActivityType.groups,
    this.groupSize = 0,
    this.groups = const [],
    this.picks = const [],
    this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'classroomId': classroomId,
        'teacherUid': teacherUid,
        'type': type.name,
        'groupSize': groupSize,
        // Firestore 는 중첩 배열을 허용하지 않으므로 맵 배열로 인코딩.
        'groups': groups.map((g) => {'members': g}).toList(),
        'picks': picks,
        'createdAt': createdAt?.toIso8601String(),
      };

  factory GroupActivity.fromMap(Map<String, dynamic> m) => GroupActivity(
        id: m['id'] as String? ?? '',
        classroomId: m['classroomId'] as String? ?? '',
        teacherUid: m['teacherUid'] as String? ?? '',
        type: GroupActivityType.fromName(m['type'] as String?),
        groupSize: (m['groupSize'] as num?)?.toInt() ?? 0,
        groups: (m['groups'] as List?)
                ?.map((e) => ((e as Map)['members'] as List?)?.map((x) => x.toString()).toList() ?? <String>[])
                .toList() ??
            const [],
        picks: (m['picks'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        createdAt: (m['createdAt'] as String?) != null ? DateTime.tryParse(m['createdAt'] as String) : null,
      );
}

/// 모둠 편성 순수 로직(테스트 대상).
class GroupMaker {
  GroupMaker._();

  /// 학생을 순서대로 size 명씩 묶는다(마지막 모둠은 더 적을 수 있음).
  static List<List<String>> chunk(List<String> students, int size) {
    final s = size < 1 ? 1 : size;
    final out = <List<String>>[];
    for (var i = 0; i < students.length; i += s) {
      out.add(students.sublist(i, min(i + s, students.length)));
    }
    return out;
  }

  /// 무작위로 섞은 뒤 size 명씩 편성.
  static List<List<String>> make(List<String> students, int size, {Random? random}) {
    final copy = [...students]..shuffle(random ?? Random());
    return chunk(copy, size);
  }
}

/// 발표 학생 추첨 순수 로직(테스트 대상).
class PresenterPicker {
  PresenterPicker._();

  /// 추첨 후보. 중복 금지면 최근 발표자를 제외하되, 모두 제외되면 전체로 리셋.
  static List<String> available(List<String> students, List<String> recent, bool allowRepeat) {
    if (allowRepeat) return [...students];
    final remaining = students.where((s) => !recent.contains(s)).toList();
    return remaining.isEmpty ? [...students] : remaining;
  }

  /// 한 명 추첨(후보 없으면 null).
  static String? pick(
    List<String> students, {
    List<String> recent = const [],
    bool allowRepeat = true,
    Random? random,
  }) {
    final cands = available(students, recent, allowRepeat);
    if (cands.isEmpty) return null;
    return cands[(random ?? Random()).nextInt(cands.length)];
  }
}
