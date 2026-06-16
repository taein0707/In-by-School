import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/growth/growth.dart';
import '../../domain/study/study_session.dart';
import '../../domain/life/life.dart';

/// Firestore persistence (offline-first — Firestore caches locally and syncs).
/// Layout: users/{uid}/state/spirit  (growth doc)
///         users/{uid}/sessions/{id} (one per session)
class StudyRepository {
  // Lazy: accessing FirebaseAuth/Firestore.instance before Firebase.initializeApp
  // throws, so resolve them at call time (keeps construction safe in tests/web).
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  Future<String> ensureUser() async {
    if (_auth.currentUser == null) {
      await _auth.signInAnonymously();
    }
    return _auth.currentUser!.uid;
  }

  // ---- account (email/password) ----
  User? get currentUser => _auth.currentUser;
  String? get email => _auth.currentUser?.email;
  bool get isEmailAccount => _auth.currentUser?.email != null;
  Stream<User?> authChanges() => _auth.authStateChanges();

  /// 회원가입. 익명 세션이 있으면 데이터를 보존한 채 계정으로 연결.
  Future<void> signUpEmail(String email, String password) async {
    final user = _auth.currentUser;
    final cred = EmailAuthProvider.credential(email: email, password: password);
    if (user != null && user.isAnonymous) {
      await user.linkWithCredential(cred);
    } else {
      await _auth.createUserWithEmailAndPassword(email: email, password: password);
    }
  }

  Future<void> signInEmail(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  Future<void> signOut() => _auth.signOut();

  /// 비밀번호 재설정 메일 발송.
  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  bool get isAnonymous => _auth.currentUser?.isAnonymous ?? false;

  /// 민감 작업(계정 삭제) 전 재인증 — 이메일 계정만 필요.
  Future<void> reauthenticate(String password) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) return;
    final cred = EmailAuthProvider.credential(email: user.email!, password: password);
    await user.reauthenticateWithCredential(cred);
  }

  /// FirebaseAuth 계정 삭제(데이터 정리 후 호출). recent-login 필요 시 throw.
  Future<void> deleteAuthUser() async {
    await _auth.currentUser?.delete();
  }

  DocumentReference<Map<String, dynamic>> _spiritDoc(String uid) =>
      _db.collection('users').doc(uid).collection('state').doc('spirit');

  DocumentReference<Map<String, dynamic>> _lifeDoc(String uid) =>
      _db.collection('users').doc(uid).collection('state').doc('life');

  CollectionReference<Map<String, dynamic>> _sessionsCol(String uid) =>
      _db.collection('users').doc(uid).collection('sessions');

  /// Load growth + recent sessions + life. Returns null on first run.
  Future<({GrowthState growth, List<StudySession> sessions, Life life})?> load() async {
    final uid = await ensureUser();
    final spiritSnap = await _spiritDoc(uid).get();
    final lifeSnap = await _lifeDoc(uid).get();
    final sessionsSnap =
        await _sessionsCol(uid).orderBy('date', descending: true).limit(100).get();

    final sessions = sessionsSnap.docs
        .map((d) => StudySession.fromMap(d.data()))
        .toList()
        .reversed
        .toList();

    if (!spiritSnap.exists && sessions.isEmpty) return null;

    final growth = spiritSnap.exists ? GrowthState.fromMap(spiritSnap.data()!) : const GrowthState();
    final life = lifeSnap.exists ? Life.fromMap(lifeSnap.data()!) : const Life();
    return (growth: growth, sessions: sessions, life: life);
  }

  Future<void> saveGrowth(GrowthState g) async {
    final uid = await ensureUser();
    await _spiritDoc(uid).set(g.toMap());
  }

  Future<void> saveLife(Life life) async {
    final uid = await ensureUser();
    await _lifeDoc(uid).set(life.toMap());
  }

  Future<void> addSession(StudySession s) async {
    final uid = await ensureUser();
    await _sessionsCol(uid).add(s.toMap());
  }

  Future<void> clear() async {
    final uid = await ensureUser();
    final batch = _db.batch();
    final sessions = await _sessionsCol(uid).get();
    for (final d in sessions.docs) {
      batch.delete(d.reference);
    }
    batch.delete(_spiritDoc(uid));
    batch.delete(_lifeDoc(uid));
    await batch.commit();
  }
}
