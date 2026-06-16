import '../../domain/presence/student_presence.dart';

// 웹에서만 실제 동작. 비-웹(모바일/VM 테스트)은 no-op 스텁으로 컴파일.
import 'presence_tracker_io.dart' if (dart.library.html) 'presence_tracker_web.dart' as impl;

/// 학생 브라우저의 참여 상태를 감지하는 추적기(웹 전용).
/// 입력(mousemove/keydown/mousedown)·가시성(visibilitychange/blur/focus)을 듣고
/// 상태가 바뀔 때 [start] 로 전달한 콜백을 호출한다.
abstract class PresenceTracker {
  /// 감지 시작. 상태가 바뀔 때마다 [onChange] 호출.
  /// (화면 캡처는 P7 의 ScreenBroadcaster 가 담당 — 여기선 참여 감지만.)
  void start(void Function(StudentPresence status) onChange);

  /// 리스너/타이머 정리.
  void dispose();
}

/// 플랫폼에 맞는 추적기 생성(웹=실제, 그 외=no-op).
PresenceTracker createPresenceTracker() => impl.createPresenceTracker();
