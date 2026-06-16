import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/firebase/assignment_repository.dart';
import '../domain/assignment/assignment.dart';
import 'account_providers.dart';

final assignmentRepositoryProvider = Provider<AssignmentRepository>((ref) => AssignmentRepository());

/// 미인증(로그아웃/전환)이면 빈 스트림 — stale 리스너 permission-denied 방지(P2-1).
bool _signedOut(Ref ref) =>
    Firebase.apps.isEmpty || ref.watch(authStateProvider).value == null;

/// 선생님: 내가 낸 숙제(최신순).
final teacherAssignmentsProvider = StreamProvider<List<Assignment>>((ref) {
  if (_signedOut(ref)) return Stream.value(const []);
  return ref.watch(assignmentRepositoryProvider).watchAssignmentsByTeacher();
});

/// 학생: 나에게 배포된 숙제(최신순).
final studentAssignmentsProvider = StreamProvider<List<Assignment>>((ref) {
  if (_signedOut(ref)) return Stream.value(const []);
  return ref.watch(assignmentRepositoryProvider).watchAssignmentsForStudent();
});

/// 학생: 내 제출 전체(목록에서 상태 조인 — assignmentId → Submission).
final mySubmissionsProvider = StreamProvider<Map<String, Submission>>((ref) {
  if (_signedOut(ref)) return Stream.value(const {});
  return ref.watch(assignmentRepositoryProvider).watchMySubmissions().map(
        (list) => {for (final s in list) s.assignmentId: s},
      );
});

/// 선생님: 한 숙제의 제출 현황(studentUid → Submission).
final submissionsForAssignmentProvider =
    StreamProvider.family<Map<String, Submission>, String>((ref, assignmentId) {
  if (_signedOut(ref)) return Stream.value(const {});
  return ref.watch(assignmentRepositoryProvider).watchSubmissionsForAssignment(assignmentId).map(
        (list) => {for (final s in list) s.studentUid: s},
      );
});
