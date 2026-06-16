import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// P7 — WebRTC 시그널링(Firestore). 플랫폼 비의존(원시값만 다룬다 — flutter_webrtc 미참조).
///
///   webrtcSessions/{sessionId}                  {teacherUid, studentUid, status, createdAt,
///                                                offer:{sdp,type}, answer:{sdp,type}}
///   webrtcSessions/{sessionId}/iceCandidates/*  {role:'student'|'teacher', candidate,
///                                                sdpMid, sdpMLineIndex, teacherUid, studentUid}
///
/// sessionId 는 screenShareRequests 문서 id 를 재사용한다(요청↔세션 1:1).
class WebrtcRepository {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  String? get uid => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _sessions => _db.collection('webrtcSessions');
  CollectionReference<Map<String, dynamic>> _ice(String sessionId) =>
      _sessions.doc(sessionId).collection('iceCandidates');

  // ---- 학생: 세션 생성 ----
  Future<void> createSession({
    required String sessionId,
    required String teacherUid,
    required String studentUid,
  }) =>
      _sessions.doc(sessionId).set({
        'sessionId': sessionId,
        'teacherUid': teacherUid,
        'studentUid': studentUid,
        'status': 'active',
        'createdAt': DateTime.now().toIso8601String(),
      });

  // ---- 학생: offer 저장 / 교사: answer 저장 ----
  Future<void> setOffer(String sessionId, String? sdp, String? type) =>
      _sessions.doc(sessionId).set({
        'offer': {'sdp': sdp, 'type': type}
      }, SetOptions(merge: true));

  Future<void> setAnswer(String sessionId, String? sdp, String? type) =>
      _sessions.doc(sessionId).set({
        'answer': {'sdp': sdp, 'type': type}
      }, SetOptions(merge: true));

  /// 세션 문서 실시간 구독(offer/answer/status 확인).
  Stream<Map<String, dynamic>?> watchSession(String sessionId) =>
      _sessions.doc(sessionId).snapshots().map((d) => d.data());

  // ---- ICE 후보 추가(보낸 쪽 role 표기 + uid 비정규화로 규칙 get() 회피) ----
  Future<void> addIce({
    required String sessionId,
    required String role, // 'student' | 'teacher'
    required String teacherUid,
    required String studentUid,
    String? candidate,
    String? sdpMid,
    int? sdpMLineIndex,
  }) =>
      _ice(sessionId).add({
        'role': role,
        'candidate': candidate,
        'sdpMid': sdpMid,
        'sdpMLineIndex': sdpMLineIndex,
        'teacherUid': teacherUid,
        'studentUid': studentUid,
      });

  /// 상대가 추가한 ICE 후보(새로 추가된 것만) 구독.
  Stream<List<Map<String, dynamic>>> watchIce({required String sessionId, required String role}) =>
      _ice(sessionId).where('role', isEqualTo: role).snapshots().map(
            (s) => s.docChanges
                .where((ch) => ch.type == DocumentChangeType.added)
                .map((ch) => ch.doc.data() ?? const <String, dynamic>{})
                .toList(),
          );

  // ---- 세션 종료(후보 정리 후 문서 삭제) ----
  Future<void> closeSession(String sessionId) async {
    final doc = _sessions.doc(sessionId);
    final ices = await _ice(sessionId).get();
    for (final d in ices.docs) {
      await d.reference.delete();
    }
    await doc.delete();
  }
}
