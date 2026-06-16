import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/firebase/presence_repository.dart';
import '../data/firebase/webrtc_repository.dart';
import '../domain/presence/student_presence.dart';
import 'account_providers.dart';
import 'classroom_providers.dart';

final presenceRepositoryProvider = Provider<PresenceRepository>((ref) => PresenceRepository());

/// P7 — WebRTC 시그널링 저장소(Firestore).
final webrtcRepositoryProvider = Provider<WebrtcRepository>((ref) => WebrtcRepository());

bool _signedOut(Ref ref) => Firebase.apps.isEmpty || ref.watch(authStateProvider).value == null;

/// 교사: 한 교실 학생들의 참여 상태(roster → presence 조인).
final classroomPresenceProvider =
    StreamProvider.family<List<Presence>, String>((ref, classroomId) {
  if (_signedOut(ref)) return Stream.value(const []);
  final roster = ref.watch(classroomStudentsProvider(classroomId)).valueOrNull ?? const [];
  final uids = roster.map((m) => m.userUid).toList();
  if (uids.isEmpty) return Stream.value(const []);
  return ref.watch(presenceRepositoryProvider).watchPresence(uids);
});

/// 학생: 나에게 온 화면 공유 요청(전체 — pending 필터는 소비처에서).
final incomingShareRequestsProvider = StreamProvider<List<ScreenShareRequest>>((ref) {
  if (_signedOut(ref)) return Stream.value(const []);
  return ref.watch(presenceRepositoryProvider).watchIncomingShareRequests();
});

/// 교사: 내가 보낸 화면 공유 요청(학생별 상태 표시).
final outgoingShareRequestsProvider = StreamProvider<List<ScreenShareRequest>>((ref) {
  if (_signedOut(ref)) return Stream.value(const []);
  return ref.watch(presenceRepositoryProvider).watchOutgoingShareRequests();
});
