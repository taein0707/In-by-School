import '../../domain/presence/student_presence.dart';
import 'presence_tracker.dart';

/// 비-웹(모바일/VM 테스트) no-op 추적기 — P6 는 웹 전용이므로 아무것도 하지 않는다.
class _NoopTracker implements PresenceTracker {
  @override
  void start(void Function(StudentPresence status) onChange) {}

  @override
  void dispose() {}
}

PresenceTracker createPresenceTracker() => _NoopTracker();
