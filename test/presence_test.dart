import 'package:flutter_test/flutter_test.dart';

import 'package:ocl_study/domain/presence/presence_evaluator.dart';
import 'package:ocl_study/domain/presence/student_presence.dart';

void main() {
  group('evaluatePresence — 상태 판정', () {
    test('화면 공유 중이면 다른 조건과 무관하게 screenSharing', () {
      expect(
        evaluatePresence(sharing: true, visible: false, hiddenFor: const Duration(minutes: 1), idleFor: const Duration(minutes: 5)),
        StudentPresence.screenSharing,
      );
    });

    test('가시 + 최근 입력이면 active', () {
      expect(
        evaluatePresence(sharing: false, visible: true, hiddenFor: Duration.zero, idleFor: const Duration(seconds: 3)),
        StudentPresence.active,
      );
    });

    test('무입력 2분 이상이면 idle', () {
      expect(
        evaluatePresence(sharing: false, visible: true, hiddenFor: Duration.zero, idleFor: const Duration(minutes: 2)),
        StudentPresence.idle,
      );
    });

    test('비가시 5초 이상이면 away', () {
      expect(
        evaluatePresence(sharing: false, visible: false, hiddenFor: const Duration(seconds: 5), idleFor: Duration.zero),
        StudentPresence.away,
      );
    });

    test('비가시지만 5초 미만이면 아직 active(유예)', () {
      expect(
        evaluatePresence(sharing: false, visible: false, hiddenFor: const Duration(seconds: 3), idleFor: Duration.zero),
        StudentPresence.active,
      );
    });

    test('away 가 idle 보다 우선', () {
      expect(
        evaluatePresence(sharing: false, visible: false, hiddenFor: const Duration(seconds: 10), idleFor: const Duration(minutes: 10)),
        StudentPresence.away,
      );
    });
  });

  group('effectivePresence — 하트비트 만료 → offline', () {
    final now = DateTime(2026, 6, 16, 14, 0, 0);

    test('최근 lastSeen 이면 저장된 상태 유지', () {
      final p = Presence(studentUid: 'a', status: StudentPresence.active, lastSeen: now.subtract(const Duration(seconds: 5)));
      expect(effectivePresence(p, now), StudentPresence.active);
    });

    test('lastSeen 이 오래되면 offline 으로 간주', () {
      final p = Presence(studentUid: 'a', status: StudentPresence.active, lastSeen: now.subtract(const Duration(seconds: 30)));
      expect(effectivePresence(p, now), StudentPresence.offline);
    });

    test('lastSeen 이 없으면 offline', () {
      const p = Presence(studentUid: 'a', status: StudentPresence.idle);
      expect(effectivePresence(p, now), StudentPresence.offline);
    });

    test('이미 offline 이면 그대로', () {
      final p = Presence(studentUid: 'a', status: StudentPresence.offline, lastSeen: now);
      expect(effectivePresence(p, now), StudentPresence.offline);
    });
  });

  group('직렬화 / enum', () {
    test('StudentPresence fromName 왕복 + 알 수 없으면 offline', () {
      for (final s in StudentPresence.values) {
        expect(StudentPresence.fromName(s.name), s);
      }
      expect(StudentPresence.fromName('garbage'), StudentPresence.offline);
    });

    test('StudentPresence 라벨/이모지 존재', () {
      for (final s in StudentPresence.values) {
        expect(s.label.isNotEmpty, true);
        expect(s.emoji.isNotEmpty, true);
      }
      expect(StudentPresence.away.isAway, true);
      expect(StudentPresence.active.isAway, false);
    });

    test('ScreenShareStatus fromName 왕복 + 폴백 pending', () {
      for (final s in ScreenShareStatus.values) {
        expect(ScreenShareStatus.fromName(s.name), s);
      }
      expect(ScreenShareStatus.fromName(null), ScreenShareStatus.pending);
    });

    test('Presence toMap/fromMap 왕복', () {
      final p = Presence(
        studentUid: 's1',
        status: StudentPresence.away,
        lastSeen: DateTime(2026, 6, 16, 14, 21, 31),
        awayCount: 3,
        lastAwayAt: DateTime(2026, 6, 16, 14, 21, 0),
      );
      final r = Presence.fromMap(p.toMap());
      expect(r.studentUid, 's1');
      expect(r.status, StudentPresence.away);
      expect(r.awayCount, 3);
      expect(r.lastSeen, p.lastSeen);
      expect(r.lastAwayAt, p.lastAwayAt);
    });

    test('Presence.fromMap 누락 필드 관대', () {
      final r = Presence.fromMap({'studentUid': 's2'});
      expect(r.status, StudentPresence.offline);
      expect(r.awayCount, 0);
      expect(r.lastSeen, isNull);
    });

    test('ScreenShareRequest toMap/fromMap 왕복', () {
      final req = ScreenShareRequest(
        id: 'r1',
        teacherUid: 't1',
        studentUid: 's1',
        status: ScreenShareStatus.accepted,
        createdAt: DateTime(2026, 6, 16, 14, 0, 0),
      );
      final r = ScreenShareRequest.fromMap(req.toMap());
      expect(r.id, 'r1');
      expect(r.teacherUid, 't1');
      expect(r.studentUid, 's1');
      expect(r.status, ScreenShareStatus.accepted);
      expect(r.createdAt, req.createdAt);
    });
  });
}
