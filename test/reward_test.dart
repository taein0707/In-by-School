import 'package:flutter_test/flutter_test.dart';
import 'package:ocl_study/domain/growth/growth.dart';

void main() {
  group('Growth.addXp — 보상 XP (Life·세션과 분리)', () {
    test('레벨업 + 잔여 XP 계산', () {
      const s = GrowthState(level: 1, xp: 0);
      final need = Growth.xpToNext(1);
      final (next, gain) = Growth.addXp(s, need + 3);
      expect(next.level, 2);
      expect(next.xp, 3);
      expect(gain.leveledUp, 1);
      expect(gain.xp, need + 3);
      expect(gain.focusedMin, 0); // 보상은 분과 무관
    });

    test('세션 지표(분/세션수/연속일/오늘분)는 변하지 않는다', () {
      const s = GrowthState(
        level: 4,
        xp: 10,
        totalMin: 240,
        totalSessions: 7,
        streakCurrent: 9,
        todayMin: 50,
      );
      final (next, _) = Growth.addXp(s, 20);
      expect(next.totalMin, 240);
      expect(next.totalSessions, 7);
      expect(next.streakCurrent, 9);
      expect(next.todayMin, 50);
      expect(next.xp, 30); // XP 만 증가
    });

    test('음수 보상은 0으로 클램프 (no-op)', () {
      const s = GrowthState(level: 2, xp: 5);
      final (next, gain) = Growth.addXp(s, -100);
      expect(next.level, 2);
      expect(next.xp, 5);
      expect(gain.xp, 0);
    });

    test('XpSource 출처별 기본 보상량', () {
      expect(XpSource.assignmentDone.defaultXp, 30);
      expect(XpSource.flashcardReview.defaultXp, 20);
      expect(XpSource.aiQuiz.defaultXp, 15);
      expect(XpSource.battle.defaultXp, 40);
      expect(XpSource.studySession.defaultXp, 0);
    });
  });
}
