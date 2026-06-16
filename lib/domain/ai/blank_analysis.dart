/// Result of AI 백지복습 분석 — narrative-first (점수보다 설명 중심).
class BlankAnalysis {
  final int understanding; // 이해도 0–100
  final List<String> understood; // 잘 이해한 개념
  final List<String> missing; // 보완 필요 / 누락 개념
  final String accuracy; // 설명 정확도
  final String review; // 복습 추천
  final String nextStudy; // 다음 공부 추천 (토리의 제안)
  const BlankAnalysis({
    required this.understanding,
    required this.understood,
    required this.missing,
    required this.accuracy,
    required this.review,
    required this.nextStudy,
  });

  static List<String> _list(dynamic v) =>
      (v as List?)?.map((e) => e.toString()).where((s) => s.trim().isNotEmpty).toList() ?? const [];

  factory BlankAnalysis.fromJson(Map<String, dynamic> j) => BlankAnalysis(
        understanding: (j['understanding'] as num?)?.round().clamp(0, 100) ?? 50,
        understood: _list(j['understood']),
        missing: _list(j['missing']),
        accuracy: j['accuracy']?.toString() ?? '',
        review: j['review']?.toString() ?? '',
        nextStudy: j['nextStudy']?.toString() ?? '',
      );

  /// Deterministic offline fallback (no LLM available).
  factory BlankAnalysis.heuristic(String text) {
    final words = text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final understanding = (40 + words * 1.6).clamp(20, 96).round();
    final sentences = text.split(RegExp(r'[.!?。\n]')).where((x) => x.trim().length > 3).length;

    final understood = <String>[];
    if (understanding >= 70) understood.add('핵심 내용을 짜임새 있게 정리했어요.');
    if (sentences >= 3) understood.add('개념을 여러 문장으로 풀어 설명했어요.');
    if (understood.isEmpty) understood.add('공부한 내용을 기억해내려 했어요. 좋은 시작이에요.');

    final missing = <String>[];
    if (words < 25) missing.add('핵심 정의가 짧게 다뤄졌어요. 한 문장 더 풀어써 보면 좋아요.');
    if (sentences < 3) missing.add('개념 간 연결(원인·결과·예시)이 더 필요해 보여요.');
    if (!RegExp('예|예시|즉|따라서|그래서').hasMatch(text)) missing.add('구체적인 예시가 빠져 있어요.');
    if (missing.isEmpty) missing.add('핵심 개념을 빠짐없이 잘 짚었어요.');

    final accuracy = understanding >= 70 ? '설명이 대체로 정확해요.' : '일부 표현이 모호해요. 용어를 정확히 다시 적어봐요.';
    final review = understanding >= 80 ? '2~3일 뒤 가볍게 다시 떠올려 보면 충분해요.' : '내일 같은 내용을 다시 백지복습 해보는 걸 추천해요.';
    final nextStudy = understanding >= 80 ? '다음 단원으로 넘어가도 좋아요.' : '오늘 자기 전 5분, 빠진 부분만 다시 보는 걸 추천해요.';
    return BlankAnalysis(
      understanding: understanding, understood: understood, missing: missing,
      accuracy: accuracy, review: review, nextStudy: nextStudy,
    );
  }
}

class QuizResult {
  final int accuracy;
  final String note;
  const QuizResult(this.accuracy, this.note);
}
