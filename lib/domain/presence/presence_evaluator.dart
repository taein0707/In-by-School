import 'student_presence.dart';

/// P6 — 학생 상태 판정(순수 함수, 웹/클라이언트 공용 · VM 테스트 가능).

/// away 로 보기까지의 비가시(다른 탭/창/최소화) 지속 시간.
const Duration kAwayAfter = Duration(seconds: 5);

/// idle 로 보기까지의 무입력 지속 시간.
const Duration kIdleAfter = Duration(minutes: 2);

/// lastSeen 이 이 시간보다 오래되면 교사 화면에서 offline 으로 간주(하트비트 누락).
const Duration kOfflineAfter = Duration(seconds: 20);

/// 학생 브라우저에서의 현재 상태 판정.
/// 우선순위: screenSharing > away(비가시 5초+) > idle(무입력 2분+) > active.
StudentPresence evaluatePresence({
  required bool sharing,
  required bool visible,
  required Duration hiddenFor,
  required Duration idleFor,
  Duration awayAfter = kAwayAfter,
  Duration idleAfter = kIdleAfter,
}) {
  if (sharing) return StudentPresence.screenSharing;
  if (!visible && hiddenFor >= awayAfter) return StudentPresence.away;
  if (idleFor >= idleAfter) return StudentPresence.idle;
  return StudentPresence.active;
}

/// 하트비트(lastSeen)가 끊겼는지 — 교사 화면의 offline 추론용.
bool isStale(DateTime? lastSeen, DateTime now, {Duration ttl = kOfflineAfter}) =>
    lastSeen == null || now.difference(lastSeen) > ttl;

/// 교사 화면에 실제로 표시할 상태 — 저장된 상태가 offline 이 아니어도
/// 하트비트가 끊겼으면 offline 으로 본다. (단, 이미 offline 이면 그대로)
StudentPresence effectivePresence(Presence p, DateTime now, {Duration ttl = kOfflineAfter}) {
  if (p.status == StudentPresence.offline) return StudentPresence.offline;
  if (isStale(p.lastSeen, now, ttl: ttl)) return StudentPresence.offline;
  return p.status;
}
