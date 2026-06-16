import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/classroom_tools/group_activity.dart';
import '../../domain/classroom_tools/seat_layout.dart';

/// 수업 활동 도구(P3-2) — seatLayouts/groupActivities.
/// teacherUid 비정규화로 보안규칙 평가, where(==) 위주 + 메모리 정렬. 기존 구조 변경 없음.
class ClassroomToolsRepository {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  String? get uid => _auth.currentUser?.uid;
  Future<String> ensureUser() async {
    if (_auth.currentUser == null) await _auth.signInAnonymously();
    return _auth.currentUser!.uid;
  }

  CollectionReference<Map<String, dynamic>> get _seats => _db.collection('seatLayouts');
  CollectionReference<Map<String, dynamic>> get _groups => _db.collection('groupActivities');

  // ---- 자리 배치(교실당 1개, 문서 id = classroomId) ----
  Future<void> saveSeatLayout({
    required String classroomId,
    required int rows,
    required int cols,
    required List<String> seats,
  }) async {
    final teacherUid = await ensureUser();
    final layout = SeatLayout(
      id: classroomId,
      classroomId: classroomId,
      teacherUid: teacherUid,
      rows: rows,
      cols: cols,
      seats: seats,
      updatedAt: DateTime.now(),
    );
    await _seats.doc(classroomId).set(layout.toMap(), SetOptions(merge: true));
  }

  Stream<SeatLayout?> watchSeatLayout(String classroomId) {
    return _seats.doc(classroomId).snapshots().map((d) => d.exists ? SeatLayout.fromMap(d.data()!) : null);
  }

  // ---- 모둠/발표 추첨 기록 ----
  Future<void> saveGroupActivity({
    required String classroomId,
    required GroupActivityType type,
    int groupSize = 0,
    List<List<String>> groups = const [],
    List<String> picks = const [],
  }) async {
    final teacherUid = await ensureUser();
    final ref = _groups.doc();
    final activity = GroupActivity(
      id: ref.id,
      classroomId: classroomId,
      teacherUid: teacherUid,
      type: type,
      groupSize: groupSize,
      groups: groups,
      picks: picks,
      createdAt: DateTime.now(),
    );
    await ref.set(activity.toMap());
  }

  /// 한 교실의 모둠/발표 기록(최신순). teacherUid 필터로 규칙 충족.
  Stream<List<GroupActivity>> watchGroupActivities(String classroomId) {
    final id = uid;
    if (id == null) return const Stream.empty();
    return _groups
        .where('classroomId', isEqualTo: classroomId)
        .where('teacherUid', isEqualTo: id)
        .snapshots()
        .map((s) {
      final list = s.docs.map((d) => GroupActivity.fromMap(d.data())).toList();
      list.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      return list;
    });
  }
}
