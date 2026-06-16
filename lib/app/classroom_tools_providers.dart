import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/firebase/classroom_tools_repository.dart';
import '../domain/classroom_tools/group_activity.dart';
import '../domain/classroom_tools/seat_layout.dart';
import 'account_providers.dart';

final classroomToolsRepositoryProvider =
    Provider<ClassroomToolsRepository>((ref) => ClassroomToolsRepository());

bool _signedOut(Ref ref) =>
    Firebase.apps.isEmpty || ref.watch(authStateProvider).value == null;

/// 교실의 저장된 자리 배치(없으면 null).
final seatLayoutProvider =
    StreamProvider.family<SeatLayout?, String>((ref, classroomId) {
  if (_signedOut(ref)) return Stream.value(null);
  return ref.watch(classroomToolsRepositoryProvider).watchSeatLayout(classroomId);
});

/// 교실의 모둠/발표 추첨 기록(최신순).
final groupActivitiesProvider =
    StreamProvider.family<List<GroupActivity>, String>((ref, classroomId) {
  if (_signedOut(ref)) return Stream.value(const []);
  return ref.watch(classroomToolsRepositoryProvider).watchGroupActivities(classroomId);
});
