import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/presence/student_presence.dart';

/// P6 — 참여 상태(presence) + 화면 공유 요청(screenShareRequests).
/// presence 는 학생 본인만 쓰고(문서 id = studentUid), 같은 교실 교사가 읽는다.
class PresenceRepository {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  String? get uid => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _presence => _db.collection('presence');
  CollectionReference<Map<String, dynamic>> get _shareReqs => _db.collection('screenShareRequests');

  // ---- 학생: 내 상태 기록(merge). away 진입 시 awayCount 증가는 호출자가 계산해 전달. ----
  Future<void> writePresence({
    required StudentPresence status,
    int? awayCount,
    DateTime? lastAwayAt,
  }) async {
    final id = uid;
    if (id == null) return;
    final data = <String, dynamic>{
      'studentUid': id,
      'status': status.name,
      'lastSeen': DateTime.now().toIso8601String(),
    };
    if (awayCount != null) data['awayCount'] = awayCount;
    if (lastAwayAt != null) data['lastAwayAt'] = lastAwayAt.toIso8601String();
    await _presence.doc(id).set(data, SetOptions(merge: true));
  }

  // ---- 교사: 교실 학생들의 presence 구독(문서 id = studentUid, whereIn 최대 30) ----
  Stream<List<Presence>> watchPresence(List<String> studentUids) {
    if (studentUids.isEmpty) return Stream.value(const []);
    final ids = studentUids.take(30).toList(); // Firestore whereIn 상한
    return _presence.where(FieldPath.documentId, whereIn: ids).snapshots().map(
          (s) => s.docs.map((d) => Presence.fromMap(d.data())).toList(),
        );
  }

  // ---- 교사: 화면 보기 요청 생성(허가 우선 — 학생 수락 전까지 캡처 불가) ----
  Future<void> requestScreenShare(String studentUid) async {
    final t = uid;
    if (t == null) return;
    final ref = _shareReqs.doc();
    await ref.set(ScreenShareRequest(
      id: ref.id,
      teacherUid: t,
      studentUid: studentUid,
      status: ScreenShareStatus.pending,
      createdAt: DateTime.now(),
    ).toMap());
  }

  // ---- 학생: 나에게 온 요청(상태별 필터는 클라에서 — 복합 인덱스 회피) ----
  Stream<List<ScreenShareRequest>> watchIncomingShareRequests() {
    final id = uid;
    if (id == null) return const Stream.empty();
    return _shareReqs.where('studentUid', isEqualTo: id).snapshots().map(
          (s) => s.docs.map((d) => ScreenShareRequest.fromMap(d.data())).toList(),
        );
  }

  // ---- 교사: 내가 보낸 요청(학생별 최신 상태 확인용) ----
  Stream<List<ScreenShareRequest>> watchOutgoingShareRequests() {
    final id = uid;
    if (id == null) return const Stream.empty();
    return _shareReqs.where('teacherUid', isEqualTo: id).snapshots().map(
          (s) => s.docs.map((d) => ScreenShareRequest.fromMap(d.data())).toList(),
        );
  }

  // ---- 학생: 요청 수락/거절 ----
  Future<void> respondShareRequest(String requestId, {required bool accept}) =>
      _shareReqs.doc(requestId).set(
        {'status': accept ? ScreenShareStatus.accepted.name : ScreenShareStatus.rejected.name},
        SetOptions(merge: true),
      );
}
