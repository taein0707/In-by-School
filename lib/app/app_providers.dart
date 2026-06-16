import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/growth/growth.dart';
import '../domain/spirit/spirit_stage.dart';
import '../domain/study/study_session.dart';
import '../domain/study/study_mode.dart';
import '../domain/ai/blank_analysis.dart';
import '../domain/life/life.dart';
import '../data/firebase/study_repository.dart';
import '../data/notifications/notification_service.dart';
import '../data/local_store.dart';

export '../domain/ai/blank_analysis.dart' show BlankAnalysis, QuizResult;

final studyRepositoryProvider = Provider<StudyRepository>((ref) => StudyRepository());

/// 시험 대비 모드의 AI 계획.
class ExamPlan {
  final int dday;
  final int dailyMin; // 하루 목표(분)
  final List<String> split; // 과목 비율
  const ExamPlan({required this.dday, required this.dailyMin, required this.split});
}

/// Result of a finished session, handed to the result screen.
class SessionResult {
  final SessionGain gain;
  final StudySession session;
  final bool abandoned;
  final BlankAnalysis? blank;
  final QuizResult? quiz;
  final List<DateTime>? reviewDates; // 암기 모드: 망각곡선 복습 예약
  final ExamPlan? examPlan; // 시험 대비 모드
  const SessionResult({
    required this.gain,
    required this.session,
    this.abandoned = false,
    this.blank,
    this.quiz,
    this.reviewDates,
    this.examPlan,
  });
}

class AppState {
  final GrowthState growth;
  final List<StudySession> sessions;
  final SessionResult? lastResult;
  final Life life;
  final CoffinRecord? coffin;
  const AppState({
    required this.growth,
    required this.sessions,
    this.lastResult,
    this.life = const Life(),
    this.coffin,
  });

  AppState copyWith({
    GrowthState? growth,
    List<StudySession>? sessions,
    SessionResult? lastResult,
    Life? life,
    CoffinRecord? coffin,
  }) =>
      AppState(
        growth: growth ?? this.growth,
        sessions: sessions ?? this.sessions,
        lastResult: lastResult ?? this.lastResult,
        life: life ?? this.life,
        coffin: coffin ?? this.coffin,
      );
}

class AppNotifier extends Notifier<AppState> {
  bool get _hasFirebase => Firebase.apps.isNotEmpty;
  StudyRepository get _repo => ref.read(studyRepositoryProvider);

  @override
  AppState build() {
    if (!_hasFirebase) {
      return _seedReturning();
    }
    _hydrate();
    return const AppState(growth: GrowthState(), sessions: []);
  }

  /// Re-load from backend (e.g. after sign-in changes the account).
  Future<void> reload() => _hydrate();

  Future<void> _hydrate() async {
    try {
      final data = await _repo.load();
      if (data != null) {
        final life = LifeEngine.evaluate(data.life, _minutesByDay(data.sessions), DateTime.now());
        state = AppState(growth: data.growth, sessions: data.sessions, life: life);
        _persistLocal();
      }
    } catch (_) {/* offline / not signed in — keep current state */}
  }

  /// Mirror life state to local storage for the background isolate.
  void _persistLocal() {
    LocalStore.saveLifeSnapshot(
      life: state.life,
      dailyMinutes: _minutesByDay(state.sessions),
      name: state.growth.name,
    );
  }

  Map<String, int> _minutesByDay(List<StudySession> sessions) {
    final m = <String, int>{};
    for (final s in sessions) {
      final k = LifeEngine.dateKey(s.date);
      m[k] = (m[k] ?? 0) + s.focusedMin;
    }
    return m;
  }

  /// Apply a finished session: grows 토리 (×2.5 under an active contract),
  /// records it, re-evaluates life, persists.
  SessionResult complete(
    StudySession session, {
    bool abandoned = false,
    BlankAnalysis? blank,
    QuizResult? quiz,
    List<DateTime>? reviewDates,
    ExamPlan? examPlan,
  }) {
    final now = DateTime.now();
    final (next, gain) = Growth.applySession(
      state.growth,
      focusedMin: session.focusedMin,
      now: now,
      xpMultiplier: state.life.xpMultiplier(now), // 계약 ×2.5 × 성장 촉진제 ×1.2
    );
    final result = SessionResult(
      gain: gain, session: session, abandoned: abandoned,
      blank: blank, quiz: quiz, reviewDates: reviewDates, examPlan: examPlan,
    );
    final newSessions = [...state.sessions, session];
    final wasDead = state.life.isDead;
    var life = LifeEngine.evaluate(state.life, _minutesByDay(newSessions), now);
    // 7일 연속마다 해독제 +1 (최대 3) — 꾸준함의 보상
    if (next.streakCurrent > state.growth.streakCurrent &&
        next.streakCurrent % 7 == 0 &&
        life.antidotes < 3) {
      life = life.copyWith(antidotes: life.antidotes + 1);
    }
    state = state.copyWith(growth: next, sessions: newSessions, lastResult: result, life: life);

    // schedule local notifications (no-op on web / if denied)
    if (reviewDates != null && !abandoned) {
      NotificationService.scheduleReviews(subject: session.subject, dates: reviewDates, spiritName: next.name);
    }
    if (!wasDead && life.state == LifeState.dead && life.diedAt != null) {
      NotificationService.scheduleGoldenWarning(diedAt: life.diedAt!, spiritName: next.name);
      NotificationService.showGoldenCountdown(
        deadline: life.diedAt!.add(const Duration(days: Life.goldenDays)),
        spiritName: next.name,
      );
    }
    // 진화 임박 — 다음 단계가 1레벨 이내면 알림
    if (!gain.stageUp && next.stageIndex < SpiritStage.all.length - 1) {
      final ns = SpiritStage.all[next.stageIndex + 1];
      if (ns.levelMin - next.level <= 1) {
        NotificationService.scheduleEvolutionSoon(spiritName: next.name, nextStage: ns.name);
      }
    }

    if (_hasFirebase && session.focusedMin >= 1) {
      _repo.addSession(session).catchError((_) {});
      _repo.saveGrowth(next).catchError((_) {});
      _repo.saveLife(life).catchError((_) {});
    }
    _persistLocal();
    return result;
  }

  /// 학습 보상 — 출처(XpSource) 무관 **통합 XP 지급 API**.
  /// Life 시스템과 독립적이다(처벌·배율 없음): 토리 성장(growth)에만 직접 가산하고
  /// 분·세션수·연속일은 건드리지 않는다. 숙제 완료·플래시카드 복습·AI 문제 풀이,
  /// 그리고 향후 배틀이 모두 이 한 경로를 공유한다. 반환값(SessionGain)으로
  /// 호출부가 레벨업/진화 연출을 트리거할 수 있다.
  SessionGain awardXp(XpSource source, int amount) {
    final (next, gain) = Growth.addXp(state.growth, amount);
    state = state.copyWith(growth: next);
    if (_hasFirebase && amount > 0) {
      _repo.saveGrowth(next).catchError((_) {});
    }
    _persistLocal();
    return gain;
  }

  /// 각성 계약 활성화 (시험기간).
  void activateContract({required DateTime examDate, required int dailyTargetMin}) {
    final life = LifeEngine.activate(state.life, examDate: examDate, dailyTargetMin: dailyTargetMin, now: DateTime.now());
    state = state.copyWith(life: life);
    if (_hasFirebase) _repo.saveLife(life).catchError((_) {});
    _persistLocal();
  }

  /// Re-evaluate life over elapsed time (call on screen open). Creates the
  /// coffin record once golden time expires. Guards against rebuild loops.
  void tickLife() {
    final wasDead = state.life.isDead;
    final life = LifeEngine.evaluate(state.life, _minutesByDay(state.sessions), DateTime.now());
    if (!wasDead && life.state == LifeState.dead && life.diedAt != null) {
      NotificationService.scheduleGoldenWarning(diedAt: life.diedAt!, spiritName: state.growth.name);
      NotificationService.showGoldenCountdown(
        deadline: life.diedAt!.add(const Duration(days: Life.goldenDays)),
        spiritName: state.growth.name,
      );
    }
    if (life.state == LifeState.coffin) {
      NotificationService.cancelGoldenWarning();
      NotificationService.cancelGoldenCountdown();
    }
    CoffinRecord? coffin = state.coffin;
    if (life.state == LifeState.coffin && coffin == null) {
      final g = state.growth;
      coffin = CoffinRecord(
        name: g.name, level: g.level, totalMin: g.totalMin,
        totalSessions: g.totalSessions, stageIndex: g.stageIndex,
        diedAt: life.diedAt ?? DateTime.now(),
      );
    }
    if (_sameLife(life, state.life) && identical(coffin, state.coffin)) return;
    state = state.copyWith(life: life, coffin: coffin);
    if (_hasFirebase) _repo.saveLife(life).catchError((_) {});
    _persistLocal();
  }

  bool _sameLife(Life a, Life b) =>
      a.state == b.state &&
      a.health == b.health &&
      a.contractActive == b.contractActive &&
      a.lastEvalDate == b.lastEvalDate &&
      a.antidotes == b.antidotes &&
      a.diedAt == b.diedAt;

  /// 성장 촉진제 사용 — 24시간 XP +20%.
  void useGrowthBooster() {
    final l = state.life;
    if (l.growthBooster <= 0) return;
    final life = l.copyWith(
      growthBooster: l.growthBooster - 1,
      xpBoostUntil: DateTime.now().add(const Duration(hours: 24)),
    );
    state = state.copyWith(life: life);
    if (_hasFirebase) _repo.saveLife(life).catchError((_) {});
    _persistLocal();
  }

  /// 해독제로 즉시 부활.
  void reviveWithAntidote() {
    final life = LifeEngine.revive(state.life);
    if (identical(life, state.life)) return;
    state = state.copyWith(life: life);
    NotificationService.cancelGoldenWarning();
    NotificationService.cancelGoldenCountdown();
    if (_hasFirebase) _repo.saveLife(life).catchError((_) {});
    _persistLocal();
  }

  /// 관 → 새 정령 시작 (기록 초기화).
  void startNewSpirit() {
    state = const AppState(growth: GrowthState(), sessions: [], life: Life());
    NotificationService.cancelAll();
    if (_hasFirebase) _repo.clear().catchError((_) {});
    _persistLocal();
  }

  /// 관 → 기억 계승 (이전 정령 경험 일부를 시작 XP로).
  void inheritMemory() {
    final r = state.coffin;
    final bonus = r != null ? LifeEngine.inheritBonusXp(r) : 0;
    var xp = bonus, level = 1;
    while (xp >= Growth.xpToNext(level)) {
      xp -= Growth.xpToNext(level);
      level += 1;
    }
    final g = GrowthState(name: r?.name ?? '토리', level: level, xp: xp);
    state = AppState(growth: g, sessions: const [], life: const Life());
    NotificationService.cancelAll();
    if (_hasFirebase) {
      _repo.clear().catchError((_) {});
      _repo.saveGrowth(g).catchError((_) {});
      _repo.saveLife(const Life()).catchError((_) {});
    }
    _persistLocal();
  }

  void rename(String name) {
    final g = state.growth.copyWith(name: name);
    state = state.copyWith(growth: g);
    if (_hasFirebase) _repo.saveGrowth(g).catchError((_) {});
  }

  void resetNew() {
    state = const AppState(growth: GrowthState(), sessions: [], life: Life());
    if (_hasFirebase) _repo.clear().catchError((_) {});
    _persistLocal();
  }
}

final appProvider = NotifierProvider<AppNotifier, AppState>(AppNotifier.new);

// ---- local-preview seed: a returning learner at 작은 정령 ----
AppState _seedReturning() {
  final base = DateTime(2026, 6, 7);
  final s = <StudySession>[
    StudySession(mode: StudyMode.free, subject: '독서', focusedMin: 35, goalMin: 0, hour: 21, date: base.subtract(const Duration(days: 4))),
    StudySession(mode: StudyMode.pomodoro, subject: '영어', focusedMin: 25, goalMin: 25, hour: 20, date: base.subtract(const Duration(days: 3))),
    StudySession(mode: StudyMode.quiz, subject: '수학', focusedMin: 40, goalMin: 40, hour: 22, accuracy: 72, date: base.subtract(const Duration(days: 2))),
    StudySession(mode: StudyMode.blank, subject: '한국사', focusedMin: 30, goalMin: 30, hour: 20, date: base.subtract(const Duration(days: 1))),
    StudySession(mode: StudyMode.free, subject: '수학', focusedMin: 45, goalMin: 0, hour: 21, date: base),
  ];
  final growth = GrowthState(
    name: '토리', level: 14, xp: 60, totalMin: 540, totalSessions: 14,
    streakCurrent: 5, streakMax: 7, lastStudyDate: base, todayMin: 0,
  );
  return AppState(growth: growth, sessions: s);
}
