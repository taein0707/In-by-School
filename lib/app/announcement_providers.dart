import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/firebase/announcement_repository.dart';
import '../domain/announcement/announcement.dart';
import 'account_providers.dart';

final announcementRepositoryProvider =
    Provider<AnnouncementRepository>((ref) => AnnouncementRepository());

bool _signedOut(Ref ref) =>
    Firebase.apps.isEmpty || ref.watch(authStateProvider).value == null;

/// 한 교실의 공지(최신순) — 교사/학생 공통.
final classroomAnnouncementsProvider =
    StreamProvider.family<List<Announcement>, String>((ref, classroomId) {
  if (_signedOut(ref)) return Stream.value(const []);
  return ref.watch(announcementRepositoryProvider).watchByClassroom(classroomId);
});

/// 교사: 내가 쓴 공지 전체(최신순).
final teacherAnnouncementsProvider = StreamProvider<List<Announcement>>((ref) {
  if (_signedOut(ref)) return Stream.value(const []);
  return ref.watch(announcementRepositoryProvider).watchByTeacher();
});
