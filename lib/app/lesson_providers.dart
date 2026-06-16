import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/firebase/lesson_repository.dart';
import '../domain/lesson/lesson.dart';
import 'account_providers.dart';

final lessonRepositoryProvider = Provider<LessonRepository>((ref) => LessonRepository());

bool _signedOut(Ref ref) => Firebase.apps.isEmpty || ref.watch(authStateProvider).value == null;

/// 교사: 내 수업 목록(최신순).
final teacherLessonsProvider = StreamProvider<List<Lesson>>((ref) {
  if (_signedOut(ref)) return Stream.value(const []);
  return ref.watch(lessonRepositoryProvider).watchLessonsByTeacher();
});

/// 한 수업 문서 구독(학생 라이브 플레이어가 세션의 lessonId 로 슬라이드를 읽음).
final lessonByIdProvider = StreamProvider.family<Lesson?, String>((ref, lessonId) {
  if (_signedOut(ref) || lessonId.isEmpty) return Stream.value(null);
  return ref.watch(lessonRepositoryProvider).watchLesson(lessonId);
});
