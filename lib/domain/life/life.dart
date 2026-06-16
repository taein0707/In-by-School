import 'dart:math' as math;

/// 토리의 생명 상태 — 시험기간 각성 계약과 사망/부활/관 시스템.
///
/// 철학 주의: 사망은 강한 게임 요소라 "동반자" 톤과 긴장 관계예요. 그래서
/// 안전 버퍼(health 3)와 쉬운 부활(해독제·골든타임 7일)을 둬서 가혹하지 않게
/// 설계했어요. 수치는 모두 조정 가능합니다.
enum LifeState { alive, danger, dead, coffin }

class Life {
  static const int maxHealth = 3;
  static const int goldenDays = 7;
  static const double contractXpMultiplier = 2.5;

  final LifeState state;
  final int health; // 0..maxHealth
  final bool contractActive;
  final DateTime? examDate;
  final int dailyTargetMin;
  final String? lastEvalDate; // yyyy-mm-dd
  final DateTime? diedAt;
  final int antidotes;        // 해독제 — 골든타임 내 부활
  final int growthBooster;    // 성장 촉진제 — 24시간 XP +20%
  final int awakeningShield;  // 각성 보호막 — 계약 실패 1회 무효화
  final int memoryCrystal;    // 기억의 결정 — 환생 시 경험치 계승
  final DateTime? xpBoostUntil;

  const Life({
    this.state = LifeState.alive,
    this.health = maxHealth,
    this.contractActive = false,
    this.examDate,
    this.dailyTargetMin = 120,
    this.lastEvalDate,
    this.diedAt,
    this.antidotes = 1,
    this.growthBooster = 1,
    this.awakeningShield = 1,
    this.memoryCrystal = 0,
    this.xpBoostUntil,
  });

  bool get isDead => state == LifeState.dead || state == LifeState.coffin;
  bool get inGoldenTime => state == LifeState.dead && diedAt != null;

  Duration goldenRemaining(DateTime now) {
    if (diedAt == null) return Duration.zero;
    final end = diedAt!.add(const Duration(days: goldenDays));
    final d = end.difference(now);
    return d.isNegative ? Duration.zero : d;
  }

  bool xpBoostActive(DateTime now) => xpBoostUntil != null && now.isBefore(xpBoostUntil!);

  /// 각성 계약(×2.5) × 성장 촉진제(×1.2) 결합 배수.
  double xpMultiplier(DateTime now) {
    var m = (contractActive && !isDead) ? contractXpMultiplier : 1.0;
    if (xpBoostActive(now)) m *= 1.2;
    return m;
  }

  Life copyWith({
    LifeState? state,
    int? health,
    bool? contractActive,
    DateTime? examDate,
    int? dailyTargetMin,
    String? lastEvalDate,
    DateTime? diedAt,
    bool clearDiedAt = false,
    int? antidotes,
    int? growthBooster,
    int? awakeningShield,
    int? memoryCrystal,
    DateTime? xpBoostUntil,
    bool clearXpBoost = false,
  }) =>
      Life(
        state: state ?? this.state,
        health: health ?? this.health,
        contractActive: contractActive ?? this.contractActive,
        examDate: examDate ?? this.examDate,
        dailyTargetMin: dailyTargetMin ?? this.dailyTargetMin,
        lastEvalDate: lastEvalDate ?? this.lastEvalDate,
        diedAt: clearDiedAt ? null : (diedAt ?? this.diedAt),
        antidotes: antidotes ?? this.antidotes,
        growthBooster: growthBooster ?? this.growthBooster,
        awakeningShield: awakeningShield ?? this.awakeningShield,
        memoryCrystal: memoryCrystal ?? this.memoryCrystal,
        xpBoostUntil: clearXpBoost ? null : (xpBoostUntil ?? this.xpBoostUntil),
      );

  Map<String, dynamic> toMap() => {
        'state': state.name,
        'health': health,
        'contractActive': contractActive,
        'examDate': examDate?.toIso8601String(),
        'dailyTargetMin': dailyTargetMin,
        'lastEvalDate': lastEvalDate,
        'diedAt': diedAt?.toIso8601String(),
        'antidotes': antidotes,
        'growthBooster': growthBooster,
        'awakeningShield': awakeningShield,
        'memoryCrystal': memoryCrystal,
        'xpBoostUntil': xpBoostUntil?.toIso8601String(),
      };

  factory Life.fromMap(Map<String, dynamic> m) => Life(
        state: LifeState.values.firstWhere((e) => e.name == m['state'], orElse: () => LifeState.alive),
        health: (m['health'] as num?)?.toInt() ?? maxHealth,
        contractActive: m['contractActive'] as bool? ?? false,
        examDate: (m['examDate'] as String?) != null ? DateTime.tryParse(m['examDate']) : null,
        dailyTargetMin: (m['dailyTargetMin'] as num?)?.toInt() ?? 120,
        lastEvalDate: m['lastEvalDate'] as String?,
        diedAt: (m['diedAt'] as String?) != null ? DateTime.tryParse(m['diedAt']) : null,
        antidotes: (m['antidotes'] as num?)?.toInt() ?? 1,
        growthBooster: (m['growthBooster'] as num?)?.toInt() ?? 1,
        awakeningShield: (m['awakeningShield'] as num?)?.toInt() ?? 1,
        memoryCrystal: (m['memoryCrystal'] as num?)?.toInt() ?? 0,
        xpBoostUntil: (m['xpBoostUntil'] as String?) != null ? DateTime.tryParse(m['xpBoostUntil']) : null,
      );
}

/// 사망 시 보존되는 기록(관).
class CoffinRecord {
  final String name;
  final int level;
  final int totalMin;
  final int totalSessions;
  final int stageIndex;
  final DateTime diedAt;
  const CoffinRecord({
    required this.name,
    required this.level,
    required this.totalMin,
    required this.totalSessions,
    required this.stageIndex,
    required this.diedAt,
  });

  Map<String, dynamic> toMap() => {
        'name': name, 'level': level, 'totalMin': totalMin,
        'totalSessions': totalSessions, 'stageIndex': stageIndex,
        'diedAt': diedAt.toIso8601String(),
      };
  factory CoffinRecord.fromMap(Map<String, dynamic> m) => CoffinRecord(
        name: m['name'] as String? ?? '토리',
        level: (m['level'] as num?)?.toInt() ?? 1,
        totalMin: (m['totalMin'] as num?)?.toInt() ?? 0,
        totalSessions: (m['totalSessions'] as num?)?.toInt() ?? 0,
        stageIndex: (m['stageIndex'] as num?)?.toInt() ?? 0,
        diedAt: DateTime.tryParse(m['diedAt'] as String? ?? '') ?? DateTime(2026),
      );
}

/// Pure transitions over [Life]. No I/O, fully testable.
class LifeEngine {
  LifeEngine._();

  static String dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  static DateTime? _parse(String? key) {
    if (key == null) return null;
    final p = key.split('-');
    if (p.length != 3) return null;
    return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }

  /// Start a contract: XP ×2.5 until [examDate]; missing the daily goal costs health.
  static Life activate(Life life, {required DateTime examDate, required int dailyTargetMin, required DateTime now}) {
    return life.copyWith(
      contractActive: true,
      state: LifeState.alive,
      health: Life.maxHealth,
      examDate: examDate,
      dailyTargetMin: dailyTargetMin,
      lastEvalDate: dateKey(_dateOnly(now)),
    );
  }

  /// Roll forward over completed days, adjusting health. Meeting the goal heals,
  /// missing it hurts; health 0 ⇒ death. Also handles golden-time → coffin and
  /// contract success (exam date reached).
  static Life evaluate(Life life, Map<String, int> minutesByDay, DateTime now) {
    // dead → golden time → coffin
    if (life.state == LifeState.dead && life.diedAt != null) {
      if (now.isAfter(life.diedAt!.add(const Duration(days: Life.goldenDays)))) {
        return life.copyWith(state: LifeState.coffin);
      }
      return life;
    }
    if (!life.contractActive) return life;

    final today = _dateOnly(now);
    var day = _parse(life.lastEvalDate) ?? today;
    var health = life.health;
    var state = life.state;
    var active = true;
    var shield = life.awakeningShield;
    DateTime? diedAt = life.diedAt;

    int guard = 0;
    while (day.isBefore(today) && guard++ < 120) {
      final met = (minutesByDay[dateKey(day)] ?? 0) >= life.dailyTargetMin;
      health = met ? math.min(Life.maxHealth, health + 1) : health - 1;
      if (health <= 0) {
        if (shield > 0) {
          // 각성 보호막: 사망을 1회 무효화하고 체력 회복
          shield -= 1;
          health = Life.maxHealth;
        } else {
          health = 0;
          state = LifeState.dead;
          diedAt = now;
          active = false;
          break;
        }
      }
      day = day.add(const Duration(days: 1));
    }

    if (active) {
      state = health <= 1 ? LifeState.danger : LifeState.alive;
      // contract fulfilled once the exam date arrives
      if (life.examDate != null && !now.isBefore(_dateOnly(life.examDate!))) {
        active = false;
        state = LifeState.alive;
        health = Life.maxHealth;
      }
    }

    return life.copyWith(
      health: health,
      state: state,
      contractActive: active,
      diedAt: diedAt,
      awakeningShield: shield,
      lastEvalDate: dateKey(today),
    );
  }

  /// 해독제로 즉시 부활 (골든타임 내).
  static Life revive(Life life) {
    if (life.state != LifeState.dead || life.antidotes <= 0) return life;
    return life.copyWith(
      state: LifeState.alive,
      health: 2,
      antidotes: life.antidotes - 1,
      clearDiedAt: true,
    );
  }

  /// 관 이후 새 정령 — 생명 상태 초기화.
  static Life fresh() => const Life();

  /// 기억 계승 시 새 정령에게 줄 시작 XP 보너스.
  static int inheritBonusXp(CoffinRecord r) => (r.level * 30).clamp(0, 2000);
}
