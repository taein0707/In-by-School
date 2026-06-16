import 'package:flutter_test/flutter_test.dart';
import 'package:ocl_study/domain/task/unified_task.dart';

UnifiedTask _t(String id, {DateTime? due, bool done = false, DateTime? created, TaskType type = TaskType.assignment}) =>
    UnifiedTask(id: id, title: id, type: type, dueDate: due, completed: done, createdAt: created, source: id);

void main() {
  group('UnifiedTasks.sorted', () {
    test('마감 임박(미완료) → 미완료(마감없음) → 완료 순', () {
      final list = UnifiedTasks.sorted([
        _t('done', done: true, created: DateTime(2026, 6, 16)),
        _t('noDue', created: DateTime(2026, 6, 10)),
        _t('dueLate', due: DateTime(2026, 7, 1)),
        _t('dueSoon', due: DateTime(2026, 6, 18)),
      ]);
      expect(list.map((e) => e.id).toList(), ['dueSoon', 'dueLate', 'noDue', 'done']);
    });

    test('마감 같으면(없음) 최신 createdAt 먼저', () {
      final list = UnifiedTasks.sorted([
        _t('old', created: DateTime(2026, 6, 1)),
        _t('new', created: DateTime(2026, 6, 15)),
      ]);
      expect(list.first.id, 'new');
    });

    test('완료 항목은 항상 뒤', () {
      final list = UnifiedTasks.sorted([
        _t('doneRecent', done: true, created: DateTime(2026, 6, 16)),
        _t('todoOld', created: DateTime(2026, 1, 1)),
      ]);
      expect(list.first.id, 'todoOld');
      expect(list.last.id, 'doneRecent');
    });

    test('TaskType 라벨', () {
      expect(TaskType.assignment.label, '일반 숙제');
      expect(TaskType.card.label, '카드 문제');
      expect(TaskType.ai.label, 'AI 문제');
    });
  });
}
