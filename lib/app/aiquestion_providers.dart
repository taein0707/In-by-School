import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/firebase/aiquestion_repository.dart';
import '../domain/aiquestion/ai_question_set.dart';
import 'account_providers.dart';

final aiQuestionRepositoryProvider = Provider<AiQuestionRepository>((ref) => AiQuestionRepository());

/// 로그아웃/계정 전환 시 stale Firestore 리스너가 옛 uid 로 읽어 permission-denied 가
/// 나는 것을 막는다 — 미인증이면 빈 스트림을 돌려준다(P2-1).
bool _signedOut(Ref ref) =>
    Firebase.apps.isEmpty || ref.watch(authStateProvider).value == null;

/// 선생님: 내가 만든 문제 세트(최신순).
final teacherQuestionSetsProvider = StreamProvider<List<AiQuestionSet>>((ref) {
  if (_signedOut(ref)) return Stream.value(const []);
  return ref.watch(aiQuestionRepositoryProvider).watchSetsByTeacher();
});

/// 학생: 나에게 배포된 문제 세트(최신순).
final studentQuestionSetsProvider = StreamProvider<List<AiQuestionSet>>((ref) {
  if (_signedOut(ref)) return Stream.value(const []);
  return ref.watch(aiQuestionRepositoryProvider).watchSetsForStudent();
});

/// 학생: 내 풀이 결과 전체(setId → result).
final myQuestionResultsProvider = StreamProvider<Map<String, AiQuestionResult>>((ref) {
  if (_signedOut(ref)) return Stream.value(const {});
  return ref.watch(aiQuestionRepositoryProvider).watchMyResults().map(
        (list) => {for (final r in list) r.setId: r},
      );
});

/// 선생님: 한 세트의 학생별 결과(studentUid → result).
final resultsForSetProvider =
    StreamProvider.family<Map<String, AiQuestionResult>, String>((ref, setId) {
  if (_signedOut(ref)) return Stream.value(const {});
  return ref.watch(aiQuestionRepositoryProvider).watchResultsForSet(setId).map(
        (list) => {for (final r in list) r.studentUid: r},
      );
});

/// 선생님: 한 세트의 문제 목록(상세 미리보기). teacherUid 필터로 규칙 충족.
final questionsForSetProvider =
    StreamProvider.family<List<AiQuestion>, String>((ref, setId) {
  if (_signedOut(ref)) return Stream.value(const []);
  return ref.watch(aiQuestionRepositoryProvider).watchQuestionsForTeacher(setId);
});
