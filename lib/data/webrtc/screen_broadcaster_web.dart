import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../firebase/webrtc_repository.dart';
import 'screen_broadcaster.dart';

/// 웹 전용 — getDisplayMedia 로 화면을 캡처해 교사에게 WebRTC offer 로 송출한다.
/// 학생 동의(허용) 이후에만 생성된다(허가 우선 원칙).
class _WebBroadcaster implements ScreenBroadcaster {
  RTCPeerConnection? _pc;
  MediaStream? _stream;
  final List<StreamSubscription<dynamic>> _subs = [];

  static const Map<String, dynamic> _config = {
    'iceServers': [
      {
        'urls': ['stun:stun.l.google.com:19302']
      }
    ]
  };

  @override
  Future<bool> start({
    required WebrtcRepository repo,
    required String sessionId,
    required String teacherUid,
    required String studentUid,
    required void Function() onEnded,
  }) async {
    try {
      _stream = await navigator.mediaDevices.getDisplayMedia({'video': true, 'audio': false});
    } catch (_) {
      // 사용자가 브라우저 공유 선택을 취소했거나 권한 거부.
      return false;
    }
    final stream = _stream;
    if (stream == null) return false;

    // 사용자가 브라우저 '공유 중지'를 누르면 자동 종료를 알린다.
    for (final track in stream.getVideoTracks()) {
      track.onEnded = () => onEnded();
    }

    final pc = await createPeerConnection(_config);
    _pc = pc;

    pc.onIceCandidate = (RTCIceCandidate cand) {
      repo.addIce(
        sessionId: sessionId,
        role: 'student',
        teacherUid: teacherUid,
        studentUid: studentUid,
        candidate: cand.candidate,
        sdpMid: cand.sdpMid,
        sdpMLineIndex: cand.sdpMLineIndex,
      );
    };

    for (final track in stream.getTracks()) {
      await pc.addTrack(track, stream);
    }

    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);
    await repo.setOffer(sessionId, offer.sdp, offer.type);

    // 교사 answer 수신.
    var answered = false;
    _subs.add(repo.watchSession(sessionId).listen((data) async {
      if (data == null) return;
      final ans = data['answer'];
      if (!answered && ans is Map) {
        answered = true;
        await pc.setRemoteDescription(
          RTCSessionDescription(ans['sdp'] as String?, ans['type'] as String?),
        );
      }
    }));

    // 교사 ICE 후보 수신.
    _subs.add(repo.watchIce(sessionId: sessionId, role: 'teacher').listen((list) async {
      for (final m in list) {
        await pc.addCandidate(RTCIceCandidate(
          m['candidate'] as String?,
          m['sdpMid'] as String?,
          (m['sdpMLineIndex'] as num?)?.toInt(),
        ));
      }
    }));

    return true;
  }

  @override
  Future<void> stop() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    final stream = _stream;
    if (stream != null) {
      for (final track in stream.getTracks()) {
        await track.stop();
      }
      await stream.dispose();
    }
    _stream = null;
    await _pc?.close();
    _pc = null;
  }
}

ScreenBroadcaster createScreenBroadcaster() => _WebBroadcaster();
