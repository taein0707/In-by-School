// 빙고(P4-1) — bingoGames/{id}. 교실 기반 턴제 빙고.
// 교사가 size(N×N)·mode(개인/모둠)·단어 풀로 생성, 학생은 자동 생성된 보드로 참여.
// 자기 차례에 단어를 부르면(call) 모두의 보드에 반영, 자기 보드를 모두 채우면 우승.
import 'dart:math';

enum BingoMode {
  individual, // 개인전
  team; // 모둠전

  static BingoMode fromName(String? s) =>
      values.firstWhere((e) => e.name == s, orElse: () => BingoMode.individual);

  String get label => this == BingoMode.team ? '모둠전' : '개인전';
}

enum BingoStatus {
  waiting, // 참가 대기
  playing,
  finished;

  static BingoStatus fromName(String? s) =>
      values.firstWhere((e) => e.name == s, orElse: () => BingoStatus.waiting);
}

class BingoGame {
  final String id;
  final String classroomId;
  final String teacherUid;
  final String title;
  final int size; // N
  final BingoMode mode;
  final List<String> words; // 단어 풀
  final List<String> turnOrder; // 참가자 uid 순서
  final String currentTurn; // 현재 차례 uid
  final List<String> calledWords; // 호출된 단어(순서대로)
  final List<String> completedUsers; // 보드를 모두 채운 uid
  final String winner; // 우승자 uid('' = 없음)
  final BingoStatus status;
  final Map<String, List<String>> boards; // uid → 보드(길이 size*size)
  final Map<String, String> names; // uid → 표시 이름(비정규화)
  final DateTime? createdAt;

  const BingoGame({
    required this.id,
    required this.classroomId,
    required this.teacherUid,
    this.title = '',
    this.size = 3,
    this.mode = BingoMode.individual,
    this.words = const [],
    this.turnOrder = const [],
    this.currentTurn = '',
    this.calledWords = const [],
    this.completedUsers = const [],
    this.winner = '',
    this.status = BingoStatus.waiting,
    this.boards = const {},
    this.names = const {},
    this.createdAt,
  });

  bool get isFinished => status == BingoStatus.finished;
  List<String>? boardOf(String uid) => boards[uid];

  Map<String, dynamic> toMap() => {
        'id': id,
        'classroomId': classroomId,
        'teacherUid': teacherUid,
        'title': title,
        'size': size,
        'mode': mode.name,
        'words': words,
        'turnOrder': turnOrder,
        'currentTurn': currentTurn,
        'calledWords': calledWords,
        'completedUsers': completedUsers,
        'winner': winner,
        'status': status.name,
        'boards': boards.map((k, v) => MapEntry(k, v)),
        'names': names,
        'createdAt': createdAt?.toIso8601String(),
      };

  factory BingoGame.fromMap(Map<String, dynamic> m) => BingoGame(
        id: m['id'] as String? ?? '',
        classroomId: m['classroomId'] as String? ?? '',
        teacherUid: m['teacherUid'] as String? ?? '',
        title: m['title'] as String? ?? '',
        size: (m['size'] as num?)?.toInt() ?? 3,
        mode: BingoMode.fromName(m['mode'] as String?),
        words: (m['words'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        turnOrder: (m['turnOrder'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        currentTurn: m['currentTurn'] as String? ?? '',
        calledWords: (m['calledWords'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        completedUsers: (m['completedUsers'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        winner: m['winner'] as String? ?? '',
        status: BingoStatus.fromName(m['status'] as String?),
        boards: (m['boards'] as Map?)?.map((k, v) =>
                MapEntry(k.toString(), (v as List?)?.map((e) => e.toString()).toList() ?? <String>[])) ??
            const {},
        names: (m['names'] as Map?)?.map((k, v) => MapEntry(k.toString(), v?.toString() ?? '')) ?? const {},
        createdAt: (m['createdAt'] as String?) != null ? DateTime.tryParse(m['createdAt'] as String) : null,
      );
}

/// 빙고 순수 로직(테스트 대상).
class BingoLogic {
  BingoLogic._();

  /// 단어 풀에서 size*size 개를 무작위로 골라 보드를 만든다.
  /// 풀이 부족하면 모자란 칸은 ''(빈칸)으로 채운다.
  static List<String> generateBoard(List<String> pool, int size, {Random? random}) {
    final cap = size * size;
    final copy = [...pool]..shuffle(random ?? Random());
    final picked = copy.take(cap).toList();
    while (picked.length < cap) {
      picked.add('');
    }
    return picked;
  }

  /// 보드의 비어있지 않은 모든 칸이 호출되었는지(블랙아웃).
  static bool isBoardComplete(List<String> board, List<String> called) {
    final calledSet = called.toSet();
    final cells = board.where((w) => w.isNotEmpty);
    if (cells.isEmpty) return false;
    return cells.every(calledSet.contains);
  }

  /// 호출된 단어로 채워진 칸 수.
  static int markedCount(List<String> board, List<String> called) {
    final calledSet = called.toSet();
    return board.where((w) => w.isNotEmpty && calledSet.contains(w)).length;
  }

  /// 다음 차례 uid(순환). 순서가 비었으면 ''.
  static String nextTurn(List<String> turnOrder, String currentTurn) {
    if (turnOrder.isEmpty) return '';
    final i = turnOrder.indexOf(currentTurn);
    if (i < 0) return turnOrder.first;
    return turnOrder[(i + 1) % turnOrder.length];
  }
}
