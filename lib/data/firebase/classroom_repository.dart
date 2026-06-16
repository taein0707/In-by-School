import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/classroom/classroom.dart';

/// 교실(classrooms) + 구성원(classroomMembers) — 신규 추가(P2-0).
/// teacherUid 비정규화로 보안규칙이 get() 없이 평가, where(==) 단일 조건만 사용.
class ClassroomRepository {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  String? get uid => _auth.currentUser?.uid;
  Future<String> ensureUser() async {
    if (_auth.currentUser == null) await _auth.signInAnonymously();
    return _auth.currentUser!.uid;
  }

  CollectionReference<Map<String, dynamic>> get _classrooms => _db.collection('classrooms');
  CollectionReference<Map<String, dynamic>> get _members => _db.collection('classroomMembers');

  /// 헷갈리는 글자(I/O/0/1)를 뺀 6자리 가입 코드.
  static String generateJoinCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random.secure();
    return List.generate(6, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  // ---- 교사: 교실 생성(+ 본인을 교사 구성원으로) ----
  Future<Classroom> createClassroom({required String name, String description = ''}) async {
    final teacherUid = await ensureUser();
    final ref = _classrooms.doc();
    final now = DateTime.now();
    final cls = Classroom(
      id: ref.id,
      teacherUid: teacherUid,
      name: name,
      description: description,
      joinCode: generateJoinCode(),
      createdAt: now,
    );
    final memId = ClassroomMember.idFor(ref.id, teacherUid);
    final member = ClassroomMember(
      id: memId,
      classroomId: ref.id,
      classroomName: name,
      userUid: teacherUid,
      teacherUid: teacherUid,
      role: ClassroomRole.teacher,
      joinedAt: now,
    );
    final batch = _db.batch();
    batch.set(ref, cls.toMap());
    batch.set(_members.doc(memId), member.toMap());
    await batch.commit();
    return cls;
  }

  // ---- 교사: 내 교실 목록(최신순) ----
  Stream<List<Classroom>> watchClassroomsByTeacher() {
    final id = uid;
    if (id == null) return const Stream.empty();
    return _classrooms.where('teacherUid', isEqualTo: id).snapshots().map((s) {
      final list = s.docs.map((d) => Classroom.fromMap(d.data())).toList();
      list.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      return list;
    });
  }

  // ---- 학생: 코드로 교실 직접 참여(P8 #4) ----
  /// 가입 코드로 교실을 찾는다(없으면 null).
  Future<Classroom?> findClassroomByJoinCode(String code) async {
    final key = code.trim().toUpperCase();
    if (key.isEmpty) return null;
    final q = await _classrooms.where('joinCode', isEqualTo: key).limit(1).get();
    if (q.docs.isEmpty) return null;
    return Classroom.fromMap(q.docs.first.data());
  }

  /// 코드로 본인을 교실에 가입시킨다(즉시, 승인 불필요).
  /// 이미 가입돼 있으면 그대로 반환. 코드가 틀리면 'not-found' 예외.
  Future<Classroom> joinClassroomByCode({required String code, required String studentName}) async {
    final uid = await ensureUser();
    final cls = await findClassroomByJoinCode(code);
    if (cls == null) {
      throw FirebaseException(plugin: 'classroom', code: 'not-found', message: '코드에 맞는 교실이 없어요.');
    }
    final memId = ClassroomMember.idFor(cls.id, uid);
    final existing = await _members.doc(memId).get();
    if (existing.exists) return cls; // 이미 참여 중 — 재기록(update) 권한 문제 회피.
    final member = ClassroomMember(
      id: memId,
      classroomId: cls.id,
      classroomName: cls.name,
      userUid: uid,
      teacherUid: cls.teacherUid,
      role: ClassroomRole.student,
      displayName: studentName,
      joinedAt: DateTime.now(),
    );
    // 보안 규칙이 코드 일치를 확인하도록 joinCode 를 함께 기록(모델 외 필드).
    await _members.doc(memId).set({...member.toMap(), 'joinCode': cls.joinCode});
    return cls;
  }

  /// 교사: 코드가 없는 옛 교실에 코드를 부여(재발급 포함).
  Future<String> ensureJoinCode(Classroom cls) async {
    if (cls.joinCode.isNotEmpty) return cls.joinCode;
    final code = generateJoinCode();
    await _classrooms.doc(cls.id).set({'joinCode': code}, SetOptions(merge: true));
    return code;
  }

  CollectionReference<Map<String, dynamic>> get _emails => _db.collection('userEmails');

  // ---- 교사: 이메일로 가입 사용자 조회(P2-2, P9 #8) ----
  // emailLower 인덱스 필드로 조회(대소문자/공백 무관 + 백필된 사용자 포함).
  // 인덱스 필드가 없는 레거시 문서는 문서 id(소문자 이메일)로 폴백한다.
  Future<({String uid, String displayName})?> findUserByEmail(String email) async {
    final key = email.trim().toLowerCase();
    if (key.isEmpty) return null;
    try {
      final q = await _emails.where('emailLower', isEqualTo: key).limit(1).get();
      if (q.docs.isNotEmpty) {
        final m = q.docs.first.data();
        final uid = m['uid'] as String? ?? '';
        if (uid.isNotEmpty) return (uid: uid, displayName: m['displayName'] as String? ?? '');
      }
    } catch (_) {/* 인덱스 미구성 등 — 레거시 경로로 폴백 */}
    final d = await _emails.doc(key).get();
    if (!d.exists) return null;
    final m = d.data()!;
    final uid = m['uid'] as String? ?? '';
    if (uid.isEmpty) return null;
    return (uid: uid, displayName: m['displayName'] as String? ?? '');
  }

  // ---- 교사: 학생을 교실에 추가(classroomMembers 생성) ----
  Future<void> addStudentToClassroom({
    required String classroomId,
    required String classroomName,
    required String studentUid,
    required String studentName,
  }) async {
    final teacherUid = await ensureUser();
    final memId = ClassroomMember.idFor(classroomId, studentUid);
    final member = ClassroomMember(
      id: memId,
      classroomId: classroomId,
      classroomName: classroomName,
      userUid: studentUid,
      teacherUid: teacherUid,
      role: ClassroomRole.student,
      displayName: studentName,
      joinedAt: DateTime.now(),
    );
    await _members.doc(memId).set(member.toMap(), SetOptions(merge: true));
  }

  // ---- 교사: 학생 제거 ----
  Future<void> removeStudentFromClassroom({required String classroomId, required String studentUid}) async {
    await _members.doc(ClassroomMember.idFor(classroomId, studentUid)).delete();
  }

  // ---- 교사: 한 교실의 학생 목록(teacherUid 필터로 규칙 충족) ----
  Stream<List<ClassroomMember>> watchStudentsInClassroom(String classroomId) {
    final id = uid;
    if (id == null) return const Stream.empty();
    return _members
        .where('classroomId', isEqualTo: classroomId)
        .where('teacherUid', isEqualTo: id)
        .snapshots()
        .map((s) {
      final list = s.docs
          .map((d) => ClassroomMember.fromMap(d.data()))
          .where((m) => m.role == ClassroomRole.student)
          .toList();
      list.sort((a, b) => a.displayName.compareTo(b.displayName));
      return list;
    });
  }

  // ---- 교사: 내 모든 교실의 학생(중복 제거) — 숙제/카드/AI 배포 대상 로스터 ----
  // teacherUid 단일 필터(자동 인덱스)로 모든 교실 구성원을 받아 학생만 추린다.
  Stream<List<ClassroomMember>> watchStudentsForTeacher() {
    final id = uid;
    if (id == null) return const Stream.empty();
    return _members.where('teacherUid', isEqualTo: id).snapshots().map((s) {
      final byUid = <String, ClassroomMember>{};
      for (final d in s.docs) {
        final m = ClassroomMember.fromMap(d.data());
        if (m.role != ClassroomRole.student) continue;
        // 한 학생이 여러 교실에 있어도 한 번만(이름은 동일).
        byUid[m.userUid] = m;
      }
      final list = byUid.values.toList();
      list.sort((a, b) => a.displayName.compareTo(b.displayName));
      return list;
    });
  }

  // ---- 공통: 내가 속한 교실(구성원 기준) ----
  Stream<List<ClassroomMember>> watchMyMemberships() {
    final id = uid;
    if (id == null) return const Stream.empty();
    return _members.where('userUid', isEqualTo: id).snapshots().map((s) {
      final list = s.docs.map((d) => ClassroomMember.fromMap(d.data())).toList();
      list.sort((a, b) => (b.joinedAt ?? DateTime(0)).compareTo(a.joinedAt ?? DateTime(0)));
      return list;
    });
  }
}
