import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../domain/account/roster.dart';
import '../../domain/account/user_profile.dart';
import '../../domain/classroom/classroom.dart';

/// 일괄 생성 결과 한 줄.
class BulkCreateResult {
  final String name;
  final String email;
  final bool ok;
  final String? error; // 실패 사유 코드(email-already-in-use 등)
  const BulkCreateResult({required this.name, required this.email, required this.ok, this.error});
}

/// 일괄 생성 요약.
class BulkCreateSummary {
  final List<BulkCreateResult> results;
  const BulkCreateSummary(this.results);
  int get created => results.where((r) => r.ok).length;
  int get failed => results.where((r) => !r.ok).length;
  List<BulkCreateResult> get failures => results.where((r) => !r.ok).toList();
}

/// P8-3 — 업로드 명단으로 학생 계정을 일괄 생성하고 교실에 자동 등록한다.
///
/// 교사 세션을 유지하기 위해 **보조 FirebaseApp** 인스턴스에서 학생 계정을 만든다
/// (기본 앱의 인증을 건드리지 않는다 — `createUserWithEmailAndPassword` 가 현재 사용자를
/// 갈아끼우는 문제를 회피하는 표준 패턴). 권한 분배:
///   - users/{uid} 본문: 갓 만든 학생 컨텍스트(보조 앱)에서 기록 → `isSelf` 규칙 충족.
///   - classroomMembers: 교사(기본 앱)가 기록 → `teacherUid == 본인` 규칙 충족.
/// 따라서 보안 규칙을 바꾸지 않아도 된다.
class BulkStudentRepository {
  static const String _appName = 'studentBulkCreator';

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  Future<FirebaseApp> _secondaryApp() async {
    try {
      return Firebase.app(_appName);
    } catch (_) {
      return Firebase.initializeApp(name: _appName, options: Firebase.app().options);
    }
  }

  /// [entries] 의 각 학생을 공통 [password] 로 생성하고 [classroomId] 에 등록한다.
  /// 이미 존재하는 이메일 등 개별 실패는 건너뛰고 요약에 담는다.
  Future<BulkCreateSummary> createStudents({
    required List<RosterEntry> entries,
    required String password,
    required String classroomId,
    required String classroomName,
    void Function(int done, int total)? onProgress,
  }) async {
    final teacherUid = _auth.currentUser?.uid;
    if (teacherUid == null) {
      throw FirebaseAuthException(code: 'no-teacher', message: '교사 로그인이 필요해요.');
    }

    final app = await _secondaryApp();
    final auth = FirebaseAuth.instanceFor(app: app);
    final db = FirebaseFirestore.instanceFor(app: app);

    final results = <BulkCreateResult>[];
    final created = <({String uid, String name, String email})>[];

    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      try {
        final cred = await auth.createUserWithEmailAndPassword(email: e.email, password: password);
        final uid = cred.user!.uid;
        // 학생 본문 — 방금 만든 학생 인증으로 기록(isSelf 충족), 첫 로그인 강제 변경 플래그.
        final profile = UserProfile(
          uid: uid,
          role: UserRole.student,
          displayName: e.name,
          studentType: StudentType.affiliated,
          mustChangePassword: true,
          createdAt: DateTime.now(),
        );
        await db.collection('users').doc(uid).set(profile.toPublicMap(), SetOptions(merge: true));
        // 교사 이메일 검색 인덱스(본인 매핑만 쓰기 가능 규칙 충족).
        await db.collection('userEmails').doc(e.email.toLowerCase()).set({
          'uid': uid,
          'displayName': e.name,
          'email': e.email,
        }, SetOptions(merge: true));
        created.add((uid: uid, name: e.name, email: e.email));
        results.add(BulkCreateResult(name: e.name, email: e.email, ok: true));
      } on FirebaseAuthException catch (ex) {
        results.add(BulkCreateResult(name: e.name, email: e.email, ok: false, error: ex.code));
      } catch (_) {
        results.add(BulkCreateResult(name: e.name, email: e.email, ok: false, error: 'unknown'));
      }
      onProgress?.call(i + 1, entries.length);
    }

    // 보조 앱 세션 정리(마지막 학생으로 로그인된 상태 해제).
    try {
      await auth.signOut();
    } catch (_) {/* 무시 */}

    // 교실 등록은 교사(기본 앱)가 일괄로.
    for (final s in created) {
      final memId = ClassroomMember.idFor(classroomId, s.uid);
      final member = ClassroomMember(
        id: memId,
        classroomId: classroomId,
        classroomName: classroomName,
        userUid: s.uid,
        teacherUid: teacherUid,
        role: ClassroomRole.student,
        displayName: s.name,
        joinedAt: DateTime.now(),
      );
      try {
        await _db.collection('classroomMembers').doc(memId).set(member.toMap(), SetOptions(merge: true));
      } catch (_) {
        // 계정은 생성됐으나 교실 등록 실패 — 결과를 실패로 강등(원인 표시).
        final idx = results.indexWhere((r) => r.email == s.email && r.ok);
        if (idx >= 0) {
          results[idx] = BulkCreateResult(name: s.name, email: s.email, ok: false, error: 'enroll-failed');
        }
      }
    }

    return BulkCreateSummary(results);
  }
}
