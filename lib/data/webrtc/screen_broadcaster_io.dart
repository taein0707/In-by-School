import '../firebase/webrtc_repository.dart';
import 'screen_broadcaster.dart';

/// 비-웹(모바일/VM) no-op — P7 은 웹 전용.
class _NoopBroadcaster implements ScreenBroadcaster {
  @override
  Future<bool> start({
    required WebrtcRepository repo,
    required String sessionId,
    required String teacherUid,
    required String studentUid,
    required void Function() onEnded,
  }) async =>
      false;

  @override
  Future<void> stop() async {}
}

ScreenBroadcaster createScreenBroadcaster() => _NoopBroadcaster();
