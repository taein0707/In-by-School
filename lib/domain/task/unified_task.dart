// 통합 과제(UnifiedTask, P2-3) — 학생 입장에서 숙제/카드 문제/AI 문제를 "문제" 하나로 통합.
// 기존 컬렉션(assignments/flashcardDecks/aiQuestionSets)은 그대로 두고, 클라이언트에서 병합만 한다.

enum TaskType {
  assignment, // 일반 숙제
  card, // 카드 문제
  ai; // AI 문제

  String get label => switch (this) {
        TaskType.assignment => '일반 숙제',
        TaskType.card => '카드 문제',
        TaskType.ai => 'AI 문제',
      };
}

class UnifiedTask {
  final String id;
  final String title;
  final TaskType type;
  final DateTime? dueDate;
  final bool completed;
  final DateTime? createdAt; // 정렬(최신)용
  final Object source; // 원본(Assignment/FlashcardDeck/AiQuestionSet) — 탭 시 적절 화면 이동

  const UnifiedTask({
    required this.id,
    required this.title,
    required this.type,
    required this.completed,
    required this.source,
    this.dueDate,
    this.createdAt,
  });
}

class UnifiedTasks {
  UnifiedTasks._();

  /// 정렬: 1) 마감 임박(미완료 + dueDate 빠른 순) 2) 미완료(마감 없음) 3) 완료(최신순).
  static List<UnifiedTask> sorted(List<UnifiedTask> tasks) {
    final list = [...tasks];
    list.sort((a, b) {
      if (a.completed != b.completed) return a.completed ? 1 : -1; // 완료는 뒤로
      if (!a.completed) {
        final ad = a.dueDate, bd = b.dueDate;
        if (ad != null && bd != null) {
          final cmp = ad.compareTo(bd);
          if (cmp != 0) return cmp; // 마감 빠른 순
        } else if (ad != null) {
          return -1; // 마감 있는 게 먼저
        } else if (bd != null) {
          return 1;
        }
      }
      return (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)); // 최신순
    });
    return list;
  }
}
