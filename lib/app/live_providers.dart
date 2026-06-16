import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/firebase/live_lesson_repository.dart';
import '../domain/lesson/live.dart';
import 'account_providers.dart';

final liveLessonRepositoryProvider = Provider<LiveLessonRepository>((ref) => LiveLessonRepository());

bool _signedOut(Ref ref) => Firebase.apps.isEmpty || ref.watch(authStateProvider).value == null;

/// 한 수업의 라이브 세션(교사 제어 / 학생 구독).
final lessonSessionProvider = StreamProvider.family<LessonSession?, String>((ref, lessonId) {
  if (_signedOut(ref)) return Stream.value(null);
  return ref.watch(liveLessonRepositoryProvider).watchSession(lessonId);
});

/// 교사: 한 수업의 학생 응답 전체(아이디어/투표/텍스트 등).
final lessonResponsesProvider = StreamProvider.family<List<LessonResponse>, String>((ref, lessonId) {
  if (_signedOut(ref)) return Stream.value(const []);
  return ref.watch(liveLessonRepositoryProvider).watchResponses(lessonId);
});

/// 학생: 내 교실에서 진행 중인 라이브 세션(없으면 null).
final liveSessionForClassroomProvider = StreamProvider.family<LessonSession?, String>((ref, classroomId) {
  if (_signedOut(ref)) return Stream.value(null);
  return ref.watch(liveLessonRepositoryProvider).watchLiveSessionForClassroom(classroomId);
});

/// 학생용 라이브 집계(워드클라우드/투표) — 교사가 쓴 doc 을 읽는다(P10-3).
typedef TallyKey = ({String coll, String lessonId, String slideId});
final liveTallyProvider = StreamProvider.family<Map<String, int>, TallyKey>((ref, key) {
  if (_signedOut(ref)) return Stream.value(const {});
  return ref
      .watch(liveLessonRepositoryProvider)
      .watchTally(collection: key.coll, lessonId: key.lessonId, slideId: key.slideId);
});

/// 교사 포인터(P10-3) — 학생이 실시간 구독.
final lessonPointerProvider = StreamProvider.family<LessonPointer?, String>((ref, lessonId) {
  if (_signedOut(ref)) return Stream.value(null);
  return ref.watch(liveLessonRepositoryProvider).watchPointer(lessonId);
});

/// 익명 질문(P10-3) — 교사 승인/거부, 학생은 승인된 것만 노출.
final lessonQuestionsProvider = StreamProvider.family<List<LessonQuestion>, String>((ref, lessonId) {
  if (_signedOut(ref)) return Stream.value(const []);
  return ref.watch(liveLessonRepositoryProvider).watchQuestions(lessonId);
});

/// 아이디어보드 포스트잇(P10-4) — 교사/학생 공용 실시간 보드.
final lessonIdeasProvider = StreamProvider.family<List<LessonIdea>, String>((ref, lessonId) {
  if (_signedOut(ref)) return Stream.value(const []);
  return ref.watch(liveLessonRepositoryProvider).watchIdeas(lessonId);
});

/// 좋아요 반응(P10-4).
final lessonReactionsProvider = StreamProvider.family<List<LessonReaction>, String>((ref, lessonId) {
  if (_signedOut(ref)) return Stream.value(const []);
  return ref.watch(liveLessonRepositoryProvider).watchReactions(lessonId);
});
