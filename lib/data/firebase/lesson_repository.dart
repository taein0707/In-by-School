import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/lesson/lesson.dart';

/// 수업(lessons) 저장소(P9-2 #6). teacherUid 비정규화로 규칙이 get() 없이 평가.
class LessonRepository {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  String? get uid => _auth.currentUser?.uid;
  CollectionReference<Map<String, dynamic>> get _lessons => _db.collection('lessons');

  Future<String> _ensure() async {
    if (_auth.currentUser == null) await _auth.signInAnonymously();
    return _auth.currentUser!.uid;
  }

  /// 교사: 새 수업 생성(제목 슬라이드 1개로 시작).
  Future<Lesson> createLesson({required String title, String classroomId = '', String classroomName = ''}) async {
    final teacherUid = await _ensure();
    final ref = _lessons.doc();
    final lesson = Lesson(
      id: ref.id,
      teacherUid: teacherUid,
      classroomId: classroomId,
      classroomName: classroomName,
      title: title,
      slides: [LessonSlide(id: ref.id, type: LessonSlideType.title, text: title)],
      createdAt: DateTime.now(),
    );
    await ref.set(lesson.toMap());
    return lesson;
  }

  Future<void> saveLesson(Lesson lesson) =>
      _lessons.doc(lesson.id).set(lesson.toMap(), SetOptions(merge: true));

  /// 한 수업 문서 구독(학생 라이브 플레이어용).
  Stream<Lesson?> watchLesson(String id) =>
      _lessons.doc(id).snapshots().map((d) => d.exists ? Lesson.fromMap(d.data()!) : null);

  Future<void> deleteLesson(String id) => _lessons.doc(id).delete();

  /// 교사: 내 수업 목록(최신순).
  Stream<List<Lesson>> watchLessonsByTeacher() {
    final id = uid;
    if (id == null) return const Stream.empty();
    return _lessons.where('teacherUid', isEqualTo: id).snapshots().map((s) {
      final list = s.docs.map((d) => Lesson.fromMap(d.data())).toList();
      list.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      return list;
    });
  }
}
