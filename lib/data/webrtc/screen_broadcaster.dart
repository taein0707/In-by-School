import '../firebase/webrtc_repository.dart';

// 웹에서만 실제 WebRTC 송출. 비-웹/VM 테스트는 no-op 스텁.
import 'screen_broadcaster_io.dart' if (dart.library.html) 'screen_broadcaster_web.dart' as impl;

/// P7 — 학생 화면 송출(웹 전용). getDisplayMedia 캡처 + RTCPeerConnection offer.
abstract class ScreenBroadcaster {
  /// 화면 캡처 + offer 송출 시작. 사용자가 브라우저 공유를 취소하면 false.
  /// 사용자가 브라우저 UI 로 공유를 끝내면 [onEnded] 가 호출된다.
  Future<bool> start({
    required WebrtcRepository repo,
    required String sessionId,
    required String teacherUid,
    required String studentUid,
    required void Function() onEnded,
  });

  /// 송출 중단(트랙 정지 + PeerConnection 종료).
  Future<void> stop();
}

ScreenBroadcaster createScreenBroadcaster() => impl.createScreenBroadcaster();
