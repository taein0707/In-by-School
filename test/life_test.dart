import 'package:flutter_test/flutter_test.dart';
import 'package:ocl_study/domain/life/life.dart';

void main() {
  final day0 = DateTime(2026, 6, 1);
  // shield 0 for deterministic death tests (default Life has a shield)
  Life activated() => LifeEngine.activate(const Life(awakeningShield: 0),
      examDate: day0.add(const Duration(days: 14)), dailyTargetMin: 120, now: day0);

  test('activate starts an alive contract at full health, XP ×2.5', () {
    final l = activated();
    expect(l.contractActive, true);
    expect(l.state, LifeState.alive);
    expect(l.health, Life.maxHealth);
    expect(l.xpMultiplier(day0), 2.5);
  });

  test('awakening shield negates one death and is consumed', () {
    final base = LifeEngine.activate(const Life(awakeningShield: 1),
        examDate: day0.add(const Duration(days: 14)), dailyTargetMin: 120, now: day0);
    final l = LifeEngine.evaluate(base, {}, day0.add(const Duration(days: 4)));
    expect(l.state, isNot(LifeState.dead));
    expect(l.awakeningShield, 0);
  });

  test('growth booster multiplies XP ×1.2 on top of contract', () {
    final l = activated().copyWith(xpBoostUntil: day0.add(const Duration(hours: 24)));
    expect(l.xpMultiplier(day0), closeTo(2.5 * 1.2, 0.001));
  });

  test('two missed days → danger', () {
    final l = LifeEngine.evaluate(activated(), {}, day0.add(const Duration(days: 2)));
    expect(l.health, 1);
    expect(l.state, LifeState.danger);
  });

  test('three missed days → death', () {
    final l = LifeEngine.evaluate(activated(), {}, day0.add(const Duration(days: 4)));
    expect(l.state, LifeState.dead);
    expect(l.health, 0);
    expect(l.diedAt, isNotNull);
    expect(l.contractActive, false);
  });

  test('meeting the daily goal keeps the spirit alive', () {
    final met = {
      LifeEngine.dateKey(day0): 130,
      LifeEngine.dateKey(day0.add(const Duration(days: 1))): 130,
    };
    final l = LifeEngine.evaluate(activated(), met, day0.add(const Duration(days: 2)));
    expect(l.state, LifeState.alive);
    expect(l.health, Life.maxHealth);
  });

  test('golden time then coffin after 7 days', () {
    final dead = LifeEngine.evaluate(activated(), {}, day0.add(const Duration(days: 4)));
    expect(dead.goldenRemaining(dead.diedAt!).inDays, 7);
    final later = LifeEngine.evaluate(dead, {}, dead.diedAt!.add(const Duration(days: 8)));
    expect(later.state, LifeState.coffin);
  });

  test('antidote revives within golden time and is consumed', () {
    final dead = LifeEngine.evaluate(activated(), {}, day0.add(const Duration(days: 4)));
    expect(dead.antidotes, 1);
    final revived = LifeEngine.revive(dead);
    expect(revived.state, LifeState.alive);
    expect(revived.antidotes, 0);
    // no antidote left → no revive
    expect(LifeEngine.revive(revived.copyWith(state: LifeState.dead)).state, LifeState.dead);
  });

  test('contract ends successfully when exam date arrives', () {
    final met = {for (int i = 0; i < 14; i++) LifeEngine.dateKey(day0.add(Duration(days: i))): 130};
    final l = LifeEngine.evaluate(activated(), met, day0.add(const Duration(days: 14)));
    expect(l.contractActive, false);
    expect(l.state, LifeState.alive);
  });

  test('inherit bonus scales with level', () {
    final r = CoffinRecord(name: '토리', level: 20, totalMin: 500, totalSessions: 12, stageIndex: 3, diedAt: day0);
    expect(LifeEngine.inheritBonusXp(r), 600);
  });
}
