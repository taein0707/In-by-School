import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/announcement/announcement.dart';

/// 공지사항(announcements) — Classroom 기반(P2-1). 단일 where(==) 만 사용, 정렬은 메모리.
class AnnouncementRepository {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  String? get uid => _auth.currentUser?.uid;
  Future<String> ensureUser() async {
    if (_auth.currentUser == null) await _auth.signInAnonymously();
    return _auth.currentUser!.uid;
  }

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('announcements');

  // ---- 교사: 공지 작성 ----
  Future<Announcement> createAnnouncement({
    required String classroomId,
    required String title,
    required String content,
    required AnnouncementType type,
  }) async {
    final teacherUid = await ensureUser();
    final ref = _col.doc();
    final now = DateTime.now();
    final a = Announcement(
      id: ref.id,
      classroomId: classroomId,
      teacherUid: teacherUid,
      title: title,
      content: content,
      type: type,
      createdAt: now,
      updatedAt: now,
    );
    await ref.set(a.toMap());
    return a;
  }

  // ---- 교사: 공지 수정 ----
  Future<void> updateAnnouncement(Announcement a) async {
    await _col.doc(a.id).set({
      'title': a.title,
      'content': a.content,
      'type': a.type.name,
      'teacherUid': a.teacherUid,
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
  }

  // ---- 교사: 공지 삭제 ----
  Future<void> deleteAnnouncement(String id) async {
    await _col.doc(id).delete();
  }

  // ---- 공통: 한 교실의 공지(최신순) ----
  Stream<List<Announcement>> watchByClassroom(String classroomId) {
    return _col.where('classroomId', isEqualTo: classroomId).snapshots().map((s) {
      final list = s.docs.map((d) => Announcement.fromMap(d.data())).toList();
      list.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      return list;
    });
  }

  // ---- 교사: 내가 쓴 공지 전체(최신순) ----
  Stream<List<Announcement>> watchByTeacher() {
    final id = uid;
    if (id == null) return const Stream.empty();
    return _col.where('teacherUid', isEqualTo: id).snapshots().map((s) {
      final list = s.docs.map((d) => Announcement.fromMap(d.data())).toList();
      list.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      return list;
    });
  }
}
