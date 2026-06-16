import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/task/unified_task.dart';
import 'aiquestion_providers.dart';
import 'assignment_providers.dart';
import 'flashcard_providers.dart';

/// 학생: 숙제 + 카드 문제 + AI 문제를 "문제"로 통합(P2-3).
/// 기존 provider 들에서 파생(클라이언트 병합) — Firestore 구조 변경 없음.
/// 모든 비동기는 valueOrNull 로 안전 접근(AsyncError rethrow 방지).
final unifiedTasksProvider = Provider<List<UnifiedTask>>((ref) {
  final assignments = ref.watch(studentAssignmentsProvider).valueOrNull ?? const [];
  final subs = ref.watch(mySubmissionsProvider).valueOrNull ?? const {};
  final decks = ref.watch(studentDecksProvider).valueOrNull ?? const [];
  final prog = ref.watch(myFlashcardProgressProvider).valueOrNull ?? const {};
  final sets = ref.watch(studentQuestionSetsProvider).valueOrNull ?? const [];
  final results = ref.watch(myQuestionResultsProvider).valueOrNull ?? const {};

  final tasks = <UnifiedTask>[];
  for (final a in assignments) {
    tasks.add(UnifiedTask(
      id: a.id,
      title: a.title,
      type: TaskType.assignment,
      dueDate: a.dueDate,
      completed: subs[a.id]?.isDone ?? false,
      createdAt: a.createdAt,
      source: a,
    ));
  }
  for (final d in decks) {
    tasks.add(UnifiedTask(
      id: d.id,
      title: d.title,
      type: TaskType.card,
      completed: prog[d.id]?.isDone ?? false,
      createdAt: d.createdAt,
      source: d,
    ));
  }
  for (final s in sets) {
    tasks.add(UnifiedTask(
      id: s.id,
      title: s.title,
      type: TaskType.ai,
      completed: results.containsKey(s.id),
      createdAt: s.createdAt,
      source: s,
    ));
  }
  return UnifiedTasks.sorted(tasks);
});
