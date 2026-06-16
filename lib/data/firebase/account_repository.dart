import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/account/user_profile.dart';
import '../../domain/account/notif_prefs.dart';
import '../../domain/notification/app_notification.dart';

/// 플랫폼(학생·선생님) 데이터 접근. 기존 StudyRepository(토리 성장)와 분리.
///
/// 최상위 컬렉션:
///   users/{uid}            — 프로필(역할/소속/FCM 토큰)
///   notifications/{id}     — 인앱 알림(FCM 트리거 소스)
///
/// 교사↔학생 관계는 교실(classrooms/classroomMembers)로 일원화됐다.
/// 요청·승인·초대코드(teacherLinks/inviteCodes) 시스템은 제거됨.
///
/// FirebaseAuth/Firestore 는 initializeApp 이전 접근 시 throw 되므로 호출 시점에
/// 지연 해석한다(StudyRepository 와 동일 패턴).
class AccountRepository {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  String? get uid => _auth.currentUser?.uid;

  /// 이메일 정규화(검색·인덱스 키 일관성) — 공백 제거 + 소문자.
  static String normalizeEmail(String email) => email.trim().toLowerCase();

  Future<String> ensureUser() async {
    if (_auth.currentUser == null) {
      await _auth.signInAnonymously();
    }
    return _auth.currentUser!.uid;
  }

  // ---- 프로필 ----
  DocumentReference<Map<String, dynamic>> _userDoc(String uid) => _db.collection('users').doc(uid);

  /// 회원가입 직후 호출 — 역할/소속을 확정해 프로필 문서를 만든다.
  /// (익명 데이터는 users/{uid}/state·sessions 에 그대로 보존됨.)
  Future<UserProfile> createProfile({
    required UserRole role,
    required String displayName,
    StudentType studentType = StudentType.independent,
    String? subject,
    OrgType? orgType,
    String? orgName,
    String? schoolId,
    String? schoolName,
    String? academyId,
    String? academyName,
  }) async {
    final uid = await ensureUser();
    final profile = UserProfile(
      uid: uid,
      role: role,
      displayName: displayName,
      email: _auth.currentUser?.email,
      studentType: studentType,
      subject: subject,
      orgType: orgType,
      orgName: orgName,
      schoolId: schoolId,
      schoolName: schoolName,
      academyId: academyId,
      academyName: academyName,
      createdAt: DateTime.now(),
    );
    // 공개 문서에는 PII(email)·토큰을 쓰지 않는다(연결 상대가 읽으므로).
    // 이메일은 FirebaseAuth, 토큰은 users/{uid}/private/push 가 보관.
    await _userDoc(uid).set(profile.toPublicMap(), SetOptions(merge: true));
    // 교사의 이메일 초대(P2-2)를 위한 이메일→uid 인덱스. 공개 프로필이 아닌 별도
    // 컬렉션(userEmails)에 본인 매핑만 기록한다(프로필엔 여전히 email 미저장).
    final email = _auth.currentUser?.email;
    if (email != null && email.isNotEmpty) {
      final key = normalizeEmail(email);
      await _db.collection('userEmails').doc(key).set({
        'uid': uid,
        'displayName': displayName,
        'email': email,
        'emailLower': key, // 검색 인덱스(P9 #8)
      }, SetOptions(merge: true));
    }
    return profile;
  }

  /// 본인 userEmails 인덱스 백필(P9 #8) — 가입 흐름을 거치지 않아 문서가 없거나
  /// emailLower 필드가 빠진 기존 사용자를, 로그인 시 검색 가능하도록 채워준다.
  /// 규칙상 본인(uid==auth.uid) 매핑만 쓰므로 안전하다.
  Future<void> ensureEmailIndex() async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null || email.isEmpty) return;
    final key = normalizeEmail(email);
    final ref = _db.collection('userEmails').doc(key);
    try {
      final snap = await ref.get();
      if (snap.exists && snap.data()?['emailLower'] != null) return; // 이미 인덱스됨
      String displayName = '';
      try {
        final p = await _userDoc(user.uid).get();
        displayName = (p.data()?['displayName'] as String?) ?? '';
      } catch (_) {}
      await ref.set({
        'uid': user.uid,
        'email': email,
        'emailLower': key,
        'displayName': displayName,
      }, SetOptions(merge: true));
    } catch (_) {/* 권한/네트워크 일시 오류는 무시(다음 로그인에 재시도) */}
  }

  Future<UserProfile?> loadProfile([String? forUid]) async {
    final id = forUid ?? uid;
    if (id == null) return null;
    final snap = await _userDoc(id).get();
    if (!snap.exists || (snap.data()?['role'] == null)) return null;
    return UserProfile.fromMap(snap.data()!);
  }

  /// 현재 로그인 사용자의 프로필 실시간 구독(역할 분기에 사용).
  Stream<UserProfile?> watchProfile() {
    final id = uid;
    if (id == null) return const Stream.empty();
    return _userDoc(id).snapshots().map((s) =>
        (s.exists && s.data()?['role'] != null) ? UserProfile.fromMap(s.data()!) : null);
  }

  Future<void> updateStudentType(StudentType type) async {
    final uid = await ensureUser();
    await _userDoc(uid).set({'studentType': type.name}, SetOptions(merge: true));
  }

  /// 일괄 생성 학생의 첫 로그인 — 임시 비밀번호를 새 비밀번호로 바꾸고 강제 플래그를 내린다(P8-3).
  /// updatePassword 가 'requires-recent-login' 을 던지면 호출부가 재로그인을 안내한다.
  Future<void> completePasswordChange(String newPassword) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(code: 'no-current-user', message: '로그인이 필요해요.');
    }
    await user.updatePassword(newPassword);
    await _userDoc(user.uid).set({'mustChangePassword': false}, SetOptions(merge: true));
  }

  // ---- FCM 토큰 (민감정보 — 본인만 접근하는 비공개 서브컬렉션) ----
  // users/{uid}/private/push.tokens[] — 보안규칙의 users/{uid}/{document=**}
  // 와일드카드로 본인만 read/write. Functions(Admin)는 우회해 읽는다.
  DocumentReference<Map<String, dynamic>> _pushDoc(String uid) =>
      _userDoc(uid).collection('private').doc('push');

  Future<void> saveFcmToken(String token) async {
    final id = uid;
    if (id == null || token.isEmpty) return;
    await _pushDoc(id).set({
      'tokens': FieldValue.arrayUnion([token]),
    }, SetOptions(merge: true));
  }

  Future<void> removeFcmToken(String token) async {
    final id = uid;
    if (id == null || token.isEmpty) return;
    await _pushDoc(id).set({
      'tokens': FieldValue.arrayRemove([token]),
    }, SetOptions(merge: true));
  }

  // ---- 알림 ----
  CollectionReference<Map<String, dynamic>> get _notifs => _db.collection('notifications');

  /// 내 알림함 실시간 구독.
  Stream<List<AppNotification>> watchNotifications() {
    final id = uid;
    if (id == null) return const Stream.empty();
    return _notifs
        .where('toUid', isEqualTo: id)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((s) => s.docs.map((d) => AppNotification.fromMap(d.data())).toList());
  }

  Future<void> markNotificationRead(String id) =>
      _notifs.doc(id).set({'read': true}, SetOptions(merge: true));

  // ---- 알림 설정(private/settings — 본인 전용) ----
  DocumentReference<Map<String, dynamic>> _settingsDoc(String uid) =>
      _userDoc(uid).collection('private').doc('settings');

  Stream<NotifPrefs> watchNotifPrefs() {
    final id = uid;
    if (id == null) return Stream.value(const NotifPrefs());
    return _settingsDoc(id)
        .snapshots()
        .map((s) => NotifPrefs.fromMap(s.data()))
        // 인증 전환(익명→이메일 로그인으로 uid 교체, 로그아웃/탈퇴로 auth=null) 시
        // 옛 uid 에 열려 있던 이 리스너가 권한 재평가로 잠깐 내뱉는 permission-denied 는
        // 일시적 산물이다(소유자 본인 읽기는 규칙상 항상 허용). 기본값으로 흡수한다.
        .handleError(
          (_) {},
          test: (e) => e is FirebaseException && e.code == 'permission-denied',
        );
  }

  Future<void> setNotifPrefs(NotifPrefs prefs) async {
    final id = uid;
    if (id == null) return;
    await _settingsDoc(id).set(prefs.toMap(), SetOptions(merge: true));
  }

  // ---- 회원 탈퇴: 연쇄 삭제 ----
  /// 한 쿼리의 모든 문서를 배치(최대 400)로 삭제.
  Future<void> _deleteQuery(Query<Map<String, dynamic>> q) async {
    final snap = await q.get();
    for (var i = 0; i < snap.docs.length; i += 400) {
      final batch = _db.batch();
      for (final d in snap.docs.skip(i).take(400)) {
        batch.delete(d.reference);
      }
      await batch.commit();
    }
  }

  /// 계정과 연관된 모든 Firestore 데이터를 삭제(Auth 삭제 전에 호출).
  /// 삭제 범위(명시):
  ///   users/{uid} 본문 + 하위(state/sessions/private)
  ///   submissions · flashcardProgress · aiQuestionResults (학생 풀이/진행)
  ///   notifications (수신/발신)
  ///   + 선생님이 만든 배포 콘텐츠와 그 하위(assignments/flashcardDecks/aiQuestionSets,
  ///     cards/questions/제출/진행/결과)까지 함께 정리.
  Future<void> purgeUserData(String uid) async {
    // 1) 학생으로서의 발자취
    await _deleteQuery(_db.collection('submissions').where('studentUid', isEqualTo: uid));
    await _deleteQuery(_db.collection('flashcardProgress').where('studentUid', isEqualTo: uid));
    await _deleteQuery(_db.collection('aiQuestionResults').where('studentUid', isEqualTo: uid));

    // 2) 선생님으로서의 배포 콘텐츠 + 하위 연쇄
    final myAssignments = await _db.collection('assignments').where('teacherUid', isEqualTo: uid).get();
    for (final a in myAssignments.docs) {
      await _deleteQuery(_db.collection('submissions').where('assignmentId', isEqualTo: a.id));
    }
    await _deleteQuery(_db.collection('assignments').where('teacherUid', isEqualTo: uid));

    final myDecks = await _db.collection('flashcardDecks').where('teacherUid', isEqualTo: uid).get();
    for (final d in myDecks.docs) {
      await _deleteQuery(_db.collection('flashcardCards').where('deckId', isEqualTo: d.id));
      await _deleteQuery(_db.collection('flashcardProgress').where('deckId', isEqualTo: d.id));
    }
    await _deleteQuery(_db.collection('flashcardDecks').where('teacherUid', isEqualTo: uid));

    final mySets = await _db.collection('aiQuestionSets').where('teacherUid', isEqualTo: uid).get();
    for (final s in mySets.docs) {
      await _deleteQuery(_db.collection('aiQuestions').where('setId', isEqualTo: s.id));
      await _deleteQuery(_db.collection('aiQuestionResults').where('setId', isEqualTo: s.id));
    }
    await _deleteQuery(_db.collection('aiQuestionSets').where('teacherUid', isEqualTo: uid));

    // 3) 알림(양측/양방향)
    await _deleteQuery(_notifs.where('toUid', isEqualTo: uid));
    await _deleteQuery(_notifs.where('fromUid', isEqualTo: uid));

    // 4) 내 문서 하위(성장/세션/비공개) + 본문
    await _deleteQuery(_userDoc(uid).collection('sessions'));
    await _deleteQuery(_userDoc(uid).collection('state'));
    await _deleteQuery(_userDoc(uid).collection('private'));
    await _userDoc(uid).delete();
  }
}
