import 'dart:math' as math;
import '../spirit/spirit_stage.dart';

/// 토리's growth state — a pure function of the user's study data.
/// (사용자 성장이 먼저, 정령 성장은 결과.)
class GrowthState {
  final String name;
  final int level;
  final int xp; // progress within the current level
  final int totalMin;
  final int totalSessions;
  final int streakCurrent;
  final int streakMax;
  final DateTime? lastStudyDate; // date-only
  final int todayMin;

  const GrowthState({
    this.name = '토리',
    this.level = 1,
    this.xp = 0,
    this.totalMin = 0,
    this.totalSessions = 0,
    this.streakCurrent = 0,
    this.streakMax = 0,
    this.lastStudyDate,
    this.todayMin = 0,
  });

  SpiritStage get stage => SpiritStage.forLevel(level);
  int get stageIndex => SpiritStage.indexForLevel(level);
  int get xpToNext => Growth.xpToNext(level);
  double get xpProgress => (xp / xpToNext).clamp(0.0, 1.0);

  GrowthState copyWith({
    String? name,
    int? level,
    int? xp,
    int? totalMin,
    int? totalSessions,
    int? streakCurrent,
    int? streakMax,
    DateTime? lastStudyDate,
    int? todayMin,
  }) =>
      GrowthState(
        name: name ?? this.name,
        level: level ?? this.level,
        xp: xp ?? this.xp,
        totalMin: totalMin ?? this.totalMin,
        totalSessions: totalSessions ?? this.totalSessions,
        streakCurrent: streakCurrent ?? this.streakCurrent,
        streakMax: streakMax ?? this.streakMax,
        lastStudyDate: lastStudyDate ?? this.lastStudyDate,
        todayMin: todayMin ?? this.todayMin,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'level': level,
        'xp': xp,
        'totalMin': totalMin,
        'totalSessions': totalSessions,
        'streakCurrent': streakCurrent,
        'streakMax': streakMax,
        'lastStudyDate': lastStudyDate?.toIso8601String(),
        'todayMin': todayMin,
      };

  factory GrowthState.fromMap(Map<String, dynamic> m) => GrowthState(
        name: m['name'] as String? ?? '토리',
        level: (m['level'] as num?)?.toInt() ?? 1,
        xp: (m['xp'] as num?)?.toInt() ?? 0,
        totalMin: (m['totalMin'] as num?)?.toInt() ?? 0,
        totalSessions: (m['totalSessions'] as num?)?.toInt() ?? 0,
        streakCurrent: (m['streakCurrent'] as num?)?.toInt() ?? 0,
        streakMax: (m['streakMax'] as num?)?.toInt() ?? 0,
        lastStudyDate: (m['lastStudyDate'] as String?) != null
            ? DateTime.tryParse(m['lastStudyDate'] as String)
            : null,
        todayMin: (m['todayMin'] as num?)?.toInt() ?? 0,
      );
}

/// What a single session changed — drives the result screen's celebration.
class SessionGain {
  final int xp;
  final int focusedMin;
  final int leveledUp; // number of levels gained
  final bool stageUp; // crossed a stage boundary (rare — the climax)
  final int beforeLevel, afterLevel, beforeStage, afterStage;

  const SessionGain({
    required this.xp,
    required this.focusedMin,
    required this.leveledUp,
    required this.stageUp,
    required this.beforeLevel,
    required this.afterLevel,
    required this.beforeStage,
    required this.afterStage,
  });
}

/// XP 보상 출처. Life 시스템(각성계약·사망·배율)과 **무관하게** 토리 성장에
/// 직접 가산되는 학습 보상의 출처를 식별한다. 향후 배틀(XpSource.battle)도
/// 동일 경로(AppNotifier.awardXp)를 사용한다.
enum XpSource {
  studySession, // 솔로 집중 세션(분 기반 applySession 으로 별도 계산)
  assignmentDone, // 숙제 완료
  flashcardReview, // 플래시카드 복습 완료
  aiQuiz, // AI 문제 풀이 완료
  battle, // 복습 경쟁전(향후)
}

extension XpSourceReward on XpSource {
  /// 출처별 기본 보상량. 호출부에서 성과(정답수 등) 기반으로 가산·대체할 수 있다.
  int get defaultXp {
    switch (this) {
      case XpSource.studySession:
        return 0;
      case XpSource.assignmentDone:
        return 30;
      case XpSource.flashcardReview:
        return 20;
      case XpSource.aiQuiz:
        return 15;
      case XpSource.battle:
        return 40;
    }
  }
}

/// Growth math. Validated pacing: levels are quick early and slow later;
/// stages span months→years. A per-day soft cap prevents cramming from
/// fast-tracking evolution.
class Growth {
  Growth._();

  static const int xpPerMin = 4;
  static const int dailySoftCap = 120; // minutes/day at full XP rate

  static int xpToNext(int level) => (40 + 2.4 * math.pow(level, 1.3)).round();

  /// Life 와 독립적으로 raw XP 를 가산하고 레벨/스테이지 변화를 계산한다.
  /// applySession 과 달리 분·세션수·연속일·날짜를 바꾸지 않는 **순수 보상** 경로다
  /// (숙제·복습·문제풀이·배틀이 공유). 음수는 0 으로 클램프.
  static (GrowthState, SessionGain) addXp(GrowthState s, int amount) {
    final add = math.max(0, amount);
    var xp = s.xp + add;
    var level = s.level;
    var leveled = 0;
    while (xp >= xpToNext(level)) {
      xp -= xpToNext(level);
      level += 1;
      leveled += 1;
    }
    final beforeStage = SpiritStage.indexForLevel(s.level);
    final afterStage = SpiritStage.indexForLevel(level);
    final next = s.copyWith(level: level, xp: xp);
    final gain = SessionGain(
      xp: add,
      focusedMin: 0,
      leveledUp: leveled,
      stageUp: afterStage > beforeStage,
      beforeLevel: s.level,
      afterLevel: level,
      beforeStage: beforeStage,
      afterStage: afterStage,
    );
    return (next, gain);
  }

  /// XP for a session, halving the rate for minutes beyond today's soft cap.
  static int xpForSession(int focusedMin, int todayMin) {
    final before = todayMin;
    final after = todayMin + focusedMin;
    final fullMin =
        math.max(0, math.min(after, dailySoftCap) - math.min(before, dailySoftCap));
    final halfMin = focusedMin - fullMin;
    return ((fullMin + halfMin * 0.5) * xpPerMin).round();
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static (GrowthState, SessionGain) applySession(
    GrowthState s, {
    required int focusedMin,
    required DateTime now,
    double xpMultiplier = 1.0, // 시험기간 각성 계약: ×2.5
  }) {
    final today = _dateOnly(now);
    final last = s.lastStudyDate == null ? null : _dateOnly(s.lastStudyDate!);
    final sameDay = last != null && last == today;

    final todayBase = sameDay ? s.todayMin : 0;
    final gainedXp = (xpForSession(focusedMin, todayBase) * xpMultiplier).round();

    var xp = s.xp + gainedXp;
    var level = s.level;
    var leveled = 0;
    while (xp >= xpToNext(level)) {
      xp -= xpToNext(level);
      level += 1;
      leveled += 1;
    }

    // streak: only counts when at least a minute was studied
    int streak = s.streakCurrent;
    if (focusedMin >= 1) {
      if (sameDay) {
        streak = s.streakCurrent == 0 ? 1 : s.streakCurrent;
      } else if (last != null && today.difference(last).inDays == 1) {
        streak = s.streakCurrent + 1;
      } else {
        streak = 1;
      }
    }

    final beforeStage = SpiritStage.indexForLevel(s.level);
    final afterStage = SpiritStage.indexForLevel(level);

    final next = s.copyWith(
      level: level,
      xp: xp,
      totalMin: s.totalMin + focusedMin,
      totalSessions: s.totalSessions + 1,
      streakCurrent: streak,
      streakMax: math.max(s.streakMax, streak),
      lastStudyDate: today,
      todayMin: todayBase + focusedMin,
    );

    final gain = SessionGain(
      xp: gainedXp,
      focusedMin: focusedMin,
      leveledUp: leveled,
      stageUp: afterStage > beforeStage,
      beforeLevel: s.level,
      afterLevel: level,
      beforeStage: beforeStage,
      afterStage: afterStage,
    );

    return (next, gain);
  }
}
