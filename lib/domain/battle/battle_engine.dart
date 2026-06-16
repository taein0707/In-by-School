import 'dart:math';

import '../flashcard/flashcard_deck.dart' show Flashcard;
import 'battle.dart';

/// 단어 경쟁전의 순수 로직 — 문제 생성·채점·동기부여 문구·이름 마스킹.
/// UI/Firebase 와 분리되어 단위 테스트가 쉽다.
class BattleEngine {
  BattleEngine._();

  /// 참가 코드(혼동 문자 제외 대문자/숫자 6자).
  static String generateJoinCode(int seed) {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // I,O,0,1 제외
    final r = Random(seed);
    return List.generate(6, (_) => alphabet[r.nextInt(alphabet.length)]).join();
  }

  /// 덱 카드로 문제 목록 생성.
  /// - choiceRatio% 만큼 앞쪽을 선택형, 나머지는 단답형.
  /// - direction 에 따라 영/한 제시 방향 결정(mixed 는 교대).
  /// - difficulty 에 따라 오답 선택지를 고른다(쉬움=무작위, 어려움=유사 길이/철자 우선).
  static List<BattleQuestion> generateQuestions({
    required List<Flashcard> cards,
    required int count,
    required int choiceRatio,
    required BattleDifficulty difficulty,
    required BattleDirection direction,
    int seed = 7,
  }) {
    final usable = cards.where((c) => c.front.trim().isNotEmpty && c.back.trim().isNotEmpty).toList();
    if (usable.isEmpty) return const [];
    final r = Random(seed);
    final pool = [...usable]..shuffle(r);

    final n = count.clamp(1, 100);
    final choiceCount = ((n * choiceRatio) / 100).round().clamp(0, n);

    final questions = <BattleQuestion>[];
    for (var i = 0; i < n; i++) {
      final card = pool[i % pool.length];
      final dir = switch (direction) {
        BattleDirection.enToKo => true, // front(영) → back(한)
        BattleDirection.koToEn => false,
        BattleDirection.mixed => i.isEven,
      };
      final prompt = dir ? card.front : card.back;
      final answer = dir ? card.back : card.front;
      final isChoice = i < choiceCount;

      if (!isChoice) {
        questions.add(BattleQuestion(prompt: prompt, answer: answer, type: BattleQType.short));
        continue;
      }
      final distractors = _distractors(
        all: usable,
        correctCard: card,
        useFront: !dir, // 정답이 front 면 오답도 front 에서
        answer: answer,
        difficulty: difficulty,
        rand: r,
      );
      final choices = [answer, ...distractors]..shuffle(r);
      questions.add(BattleQuestion(
        prompt: prompt,
        answer: answer,
        choices: choices,
        type: BattleQType.choice,
      ));
    }
    return questions;
  }

  static List<String> _distractors({
    required List<Flashcard> all,
    required Flashcard correctCard,
    required bool useFront,
    required String answer,
    required BattleDifficulty difficulty,
    required Random rand,
  }) {
    final candidates = all
        .where((c) => c.id != correctCard.id)
        .map((c) => useFront ? c.front : c.back)
        .where((t) => t.trim().isNotEmpty && t != answer)
        .toSet()
        .toList();
    if (candidates.isEmpty) return const [];

    if (difficulty == BattleDifficulty.hard) {
      // 정답과 길이·첫 글자가 비슷한 후보 우선(혼동 유도).
      candidates.sort((a, b) => _similarity(b, answer).compareTo(_similarity(a, answer)));
    } else {
      candidates.shuffle(rand);
      if (difficulty == BattleDifficulty.normal) {
        // 보통: 절반 정도는 유사도 높은 것을 섞는다.
        candidates.sort((a, b) {
          final byLen = (a.length - answer.length).abs().compareTo((b.length - answer.length).abs());
          return rand.nextBool() ? byLen : 0;
        });
      }
    }
    return candidates.take(3).toList();
  }

  /// 단순 유사도 — 첫 글자 일치 + 길이 근접도(0~3).
  static int _similarity(String a, String b) {
    var s = 0;
    if (a.isNotEmpty && b.isNotEmpty && a[0].toLowerCase() == b[0].toLowerCase()) s += 2;
    if ((a.length - b.length).abs() <= 1) s += 1;
    return s;
  }

  // ---- 채점 ----
  static const int basePoints = 100;

  /// 연속 정답 보너스 — 5연속 +50, 10연속 +100, 15연속 +150 …(5의 배수마다).
  static int streakBonus(int newStreak) =>
      (newStreak > 0 && newStreak % 5 == 0) ? (newStreak ~/ 5) * 50 : 0;

  /// 한 문제 채점 결과(획득 점수, 갱신된 연속수).
  static ({int points, int streak}) score({required int prevStreak, required bool correct}) {
    if (!correct) return (points: 0, streak: 0);
    final streak = prevStreak + 1;
    return (points: basePoints + streakBonus(streak), streak: streak);
  }

  /// 단답형 정답 비교(공백/대소문자 무시).
  static bool isShortCorrect(String given, String answer) =>
      _norm(given) == _norm(answer);

  static String _norm(String s) => s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  /// 학생 화면 동기부여 문구 — **순위(등수)는 절대 노출하지 않는다.**
  static String motivation(int streak) {
    if (streak >= 8) return '🔥 연속 정답 $streak개';
    if (streak >= 5) return '⚡ 상위권 진입 중';
    if (streak >= 3) return '🚀 좋은 흐름입니다';
    return '🌟 계속 도전해보세요';
  }

  /// 결과 발표용 이름 마스킹 — '이태인' → '이○○', 'Kim' → 'K○○'.
  static String maskName(String name) {
    final n = name.trim();
    if (n.isEmpty) return '○○○';
    if (n.length == 1) return '$n○';
    return n[0] + '○' * (n.length - 1);
  }
}
