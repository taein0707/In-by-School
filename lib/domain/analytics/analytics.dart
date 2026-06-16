import '../study/study_session.dart';
import '../study/study_mode.dart';
import '../growth/growth.dart';

/// Rule-based learning analytics. No LLM — deterministic, instant, offline.
/// The same insight is phrased with more precision as 토리's stage rises
/// (per the manifesto: 단계↑ = 기능 수 아니라 분석 깊이·설명 품질↑).
class Analytics {
  Analytics._();

  /// 0 = 알/빛의 점, 1 = 작은/정령, 2 = 고급~수호, 3 = 대~아카이브
  static int depthForStage(int stageIndex) {
    if (stageIndex <= 1) return 0;
    if (stageIndex <= 3) return 1;
    if (stageIndex <= 6) return 2;
    return 3;
  }

  // ---- the one line on Home ("오늘의 한 줄 분석") ----
  static String homeOneLiner(List<StudySession> sessions, GrowthState g) {
    final depth = depthForStage(g.stageIndex);
    final m = _Metrics.from(sessions, g);

    if (depth == 0) {
      if (g.todayMin > 0) return '오늘 ${g.todayMin}분 공부했어요.';
      return '오늘도 함께 시작해요.';
    }

    // trend takes priority when clearly rising
    if (m.trend > 6) {
      return depth >= 2 ? '집중 시간이 꾸준히 길어지고 있어요.' : '요즘 집중이 길어지고 있어요.';
    }
    if (m.peakHour != null) {
      switch (depth) {
        case 1:
          return '${_band(m.peakHour!)} 시간대 집중력이 높아요.';
        case 2:
          return '${_range(m.peakHour!)}에 집중이 가장 잘 돼요.';
        default:
          final w = m.weeks.clamp(1, 12);
          return '최근 $w주 데이터를 보면 ${_range(m.peakHour!)}에 가장 높은 집중도를 보여요.';
      }
    }
    if (m.topSubject != null) return '최근 ${m.topSubject} 비중이 높았어요.';
    return g.todayMin > 0 ? '오늘 ${g.todayMin}분 공부했어요.' : '오늘도 함께 시작해요.';
  }

  // ---- weekly insights on the 기록 screen ----
  static List<String> weeklyInsights(List<StudySession> sessions, GrowthState g) {
    final depth = depthForStage(g.stageIndex);
    final m = _Metrics.from(sessions, g);
    final out = <String>[];

    if (m.topSubject != null) {
      out.add(depth >= 2
          ? '최근 학습의 약 ${m.topShare}%가 ${m.topSubject}에 집중됐어요.'
          : '최근 ${m.topSubject} 공부 비중이 가장 높았어요.');
    }
    if (m.peakHour != null) {
      out.add(depth >= 3
          ? '${_range(m.peakHour!)}에 가장 높은 집중도를 보이고 있어요.'
          : '${_band(m.peakHour!)} 시간대 집중이 좋아요.');
    }
    if (m.trend > 6) {
      out.add('세션당 집중 시간이 길어지는 추세예요.');
    } else if (m.trend < -6) {
      out.add('세션당 집중 시간이 짧아지고 있어요. 무리하지 말아요.');
    }
    if (m.neglected != null) {
      out.add('${m.neglected} 복습 주기가 길어지고 있어요. 한 번 돌아봐요.');
    }
    if (depth >= 2 && m.avgLen > 0) {
      out.add('한 번 공부할 때 평균 ${m.avgLen}분 집중해요.');
    }
    if (out.isEmpty) out.add('데이터가 쌓이면 더 깊은 분석을 보여줄게요.');
    return out;
  }

  // ---- personalized study methods ----
  static List<String> methodTips(List<StudySession> sessions, GrowthState g) {
    final m = _Metrics.from(sessions, g);
    final out = <String>[];
    final t = m.topSubject;
    if (t != null) {
      if (_isMemoryHeavy(t)) {
        out.add('$t은(는) 짧고 자주 복습하는 방식이 적합해 보여요.');
      } else if (_isProblemHeavy(t)) {
        out.add('$t은(는) 현재 학습 방식이 잘 맞고 있어요.');
      } else {
        out.add('$t은(는) 복습 비율을 조금 더 늘려보면 좋아요.');
      }
    }
    if (m.avgLen > 0 && m.avgLen < 18) {
      out.add('집중이 짧게 끊길 땐 포모도로로 호흡을 잡아봐요.');
    }
    if (out.isEmpty) out.add('데이터를 모아 당신에게 맞는 공부법을 찾아줄게요.');
    return out;
  }

  // ---- recommended mode for Home / setup (launch modes only) ----
  static ({StudyMode mode, String reason}) recommendMode(
      List<StudySession> sessions, GrowthState g) {
    final m = _Metrics.from(sessions, g);
    final soft = depthForStage(g.stageIndex) == 0;
    if (m.avgLen > 0 && m.avgLen < 18 && m.recentCount >= 2) {
      return (mode: StudyMode.pomodoro, reason: _soft(soft, '짧은 집중 패턴이 많아 포모도로가 더 적합해 보여요.'));
    }
    if (m.trend > 6) {
      return (mode: StudyMode.free, reason: _soft(soft, '집중 시간이 길어지고 있어 자유 공부를 추천해요.'));
    }
    final top = m.topSubject;
    if (top != null && _isMemoryHeavy(top)) {
      return (mode: StudyMode.memory, reason: _soft(soft, '$top 같은 암기 과목은 짧게 자주 복습이 좋아요. 암기 모드를 추천해요.'));
    }
    if (top != null && _isProblemHeavy(top)) {
      return (mode: StudyMode.quiz, reason: _soft(soft, '$top은(는) 문제풀이로 취약 유형을 점검해 봐요.'));
    }
    return (mode: StudyMode.blank, reason: _soft(soft, '개념 정리가 쌓일 때예요. 백지복습으로 이해도를 확인해 봐요.'));
  }

  // ---- per-session feedback for the result screen ----
  static List<String> resultFeedback(SessionGain gain, StudySession s, GrowthState afterState) {
    final depth = depthForStage(afterState.stageIndex);
    final out = <String>[];
    if (s.goalMin > 0 && gain.focusedMin >= s.goalMin) {
      out.add('오늘 목표 시간을 넘겨 달성했어요.');
    } else if (s.goalMin > 0) {
      out.add('목표 ${s.goalMin}분 중 ${gain.focusedMin}분 집중했어요.');
    } else {
      out.add('${gain.focusedMin}분 집중했어요.');
    }
    if (afterState.streakCurrent >= 3) {
      out.add('${afterState.streakCurrent}일 연속 이어가고 있어요.');
    }
    if (depth >= 2) out.add('집중 시간이 꾸준히 늘어나고 있어요.');
    return out;
  }

  // ---- helpers ----
  static String _soft(bool soft, String s) =>
      soft ? '오늘은 가볍게 시작해 볼까요? ${s.replaceAll('추천해요.', '어때요?')}' : s;

  static String _band(int h) {
    if (h < 6) return '새벽';
    if (h < 12) return '오전';
    if (h < 18) return '오후';
    return '저녁';
  }

  static String _range(int h) {
    final lo = (h - 1).clamp(0, 23);
    final hi = (h + 1).clamp(0, 23);
    final band = _band(h);
    return '$band $lo~$hi시';
  }

  static bool _isMemoryHeavy(String s) => RegExp('영어|단어|한국사|암기|생물|국사').hasMatch(s);
  static bool _isProblemHeavy(String s) => RegExp('수학|물리|화학|문제').hasMatch(s);
}

/// Derived metrics over a session window.
class _Metrics {
  final int? peakHour;
  final double trend; // last-half minus first-half avg focusedMin
  final String? topSubject;
  final int topShare; // % of recent minutes
  final String? neglected;
  final int avgLen;
  final int recentCount;
  final int weeks;

  _Metrics({
    this.peakHour,
    this.trend = 0,
    this.topSubject,
    this.topShare = 0,
    this.neglected,
    this.avgLen = 0,
    this.recentCount = 0,
    this.weeks = 1,
  });

  factory _Metrics.from(List<StudySession> sessions, GrowthState g) {
    final valid = sessions.where((s) => s.focusedMin > 0).toList();
    if (valid.isEmpty) return _Metrics();

    // peak hour by total focused minutes
    final byHour = <int, int>{};
    for (final s in valid) {
      byHour[s.hour] = (byHour[s.hour] ?? 0) + s.focusedMin;
    }
    int? peak;
    var peakV = -1;
    byHour.forEach((h, v) {
      if (v > peakV) { peakV = v; peak = h; }
    });

    // subject shares
    final bySubj = <String, int>{};
    for (final s in valid) {
      bySubj[s.subject] = (bySubj[s.subject] ?? 0) + s.focusedMin;
    }
    String? top;
    var topV = -1;
    bySubj.forEach((k, v) {
      if (v > topV) { topV = v; top = k; }
    });
    final totalMin = bySubj.values.fold<int>(0, (a, b) => a + b);
    final share = totalMin > 0 ? ((topV / totalMin) * 100).round() : 0;

    // neglected subject: known subject not seen in the last 4 sessions
    final recentSubjects = valid.reversed.take(4).map((s) => s.subject).toSet();
    String? neglected;
    for (final k in bySubj.keys) {
      if (!recentSubjects.contains(k)) { neglected = k; break; }
    }

    // trend over the last 6 sessions
    final last = valid.length > 6 ? valid.sublist(valid.length - 6) : valid;
    double trend = 0;
    if (last.length >= 2) {
      final half = last.length ~/ 2;
      final a = last.sublist(0, half).fold<int>(0, (s, x) => s + x.focusedMin) / half;
      final b = last.sublist(half).fold<int>(0, (s, x) => s + x.focusedMin) / (last.length - half);
      trend = b - a;
    }

    final avgLen = (valid.fold<int>(0, (s, x) => s + x.focusedMin) / valid.length).round();

    // weeks of data span
    final dates = valid.map((s) => s.date).toList()..sort();
    final spanDays = dates.last.difference(dates.first).inDays;
    final weeks = (spanDays / 7).ceil().clamp(1, 52);

    return _Metrics(
      peakHour: peak,
      trend: trend,
      topSubject: top,
      topShare: share,
      neglected: neglected,
      avgLen: avgLen,
      recentCount: last.length,
      weeks: weeks,
    );
  }
}
