import 'package:flutter_test/flutter_test.dart';
import 'package:ocl_study/domain/battle/battle.dart';
import 'package:ocl_study/domain/battle/battle_engine.dart';
import 'package:ocl_study/domain/flashcard/flashcard_deck.dart';

List<Flashcard> _deck(int n) => List.generate(
      n,
      (i) => Flashcard(id: 'c$i', deckId: 'd', front: 'word$i', back: '뜻$i', order: i),
    );

void main() {
  group('BattleEngine.score — 점수·연속 보너스', () {
    test('정답 기본 +100', () {
      final r = BattleEngine.score(prevStreak: 0, correct: true);
      expect(r.points, 100);
      expect(r.streak, 1);
    });
    test('오답은 0점·연속 리셋', () {
      final r = BattleEngine.score(prevStreak: 7, correct: false);
      expect(r.points, 0);
      expect(r.streak, 0);
    });
    test('5연속 +50, 10연속 +100, 15연속 +150', () {
      expect(BattleEngine.score(prevStreak: 4, correct: true).points, 150); // 5연속
      expect(BattleEngine.score(prevStreak: 9, correct: true).points, 200); // 10연속
      expect(BattleEngine.score(prevStreak: 14, correct: true).points, 250); // 15연속
      expect(BattleEngine.score(prevStreak: 5, correct: true).points, 100); // 6연속(보너스 없음)
    });
  });

  group('BattleEngine.generateQuestions — 비율/방향', () {
    test('선택형 비율 75% → 20문제 중 15선택/5단답', () {
      final qs = BattleEngine.generateQuestions(
        cards: _deck(12),
        count: 20,
        choiceRatio: 75,
        difficulty: BattleDifficulty.normal,
        direction: BattleDirection.enToKo,
        seed: 1,
      );
      expect(qs.length, 20);
      expect(qs.where((q) => q.type == BattleQType.choice).length, 15);
      expect(qs.where((q) => q.type == BattleQType.short).length, 5);
    });

    test('선택형 문제는 정답이 보기에 포함되고 4지선다', () {
      final qs = BattleEngine.generateQuestions(
        cards: _deck(10),
        count: 5,
        choiceRatio: 100,
        difficulty: BattleDifficulty.easy,
        direction: BattleDirection.enToKo,
        seed: 2,
      );
      for (final q in qs) {
        expect(q.choices.contains(q.answer), isTrue);
        expect(q.choices.length, 4);
      }
    });

    test('영→한 방향: 제시어=front, 정답=back', () {
      final qs = BattleEngine.generateQuestions(
        cards: _deck(6),
        count: 3,
        choiceRatio: 0,
        difficulty: BattleDifficulty.easy,
        direction: BattleDirection.enToKo,
        seed: 3,
      );
      expect(qs.first.prompt.startsWith('word'), isTrue);
      expect(qs.first.answer.startsWith('뜻'), isTrue);
    });

    test('빈 덱은 빈 문제', () {
      expect(
          BattleEngine.generateQuestions(
            cards: const [],
            count: 10,
            choiceRatio: 50,
            difficulty: BattleDifficulty.normal,
            direction: BattleDirection.mixed,
          ),
          isEmpty);
    });
  });

  group('BattleEngine 기타', () {
    test('단답형 채점은 공백·대소문자 무시', () {
      expect(BattleEngine.isShortCorrect('  Apple ', 'apple'), isTrue);
      expect(BattleEngine.isShortCorrect('grape', 'apple'), isFalse);
    });
    test('이름 마스킹', () {
      expect(BattleEngine.maskName('이태인'), '이○○');
      expect(BattleEngine.maskName('김'), '김○');
      expect(BattleEngine.maskName(''), '○○○');
    });
    test('동기부여 문구에는 숫자 등수가 없다(상위권 표현은 허용)', () {
      for (var s = 0; s < 20; s++) {
        final m = BattleEngine.motivation(s);
        expect(RegExp(r'\d+\s*위').hasMatch(m), isFalse); // "17위" 같은 등수 금지
      }
      expect(BattleEngine.motivation(8), contains('연속 정답'));
    });
    test('참가 코드는 6자, 혼동 문자 제외', () {
      final code = BattleEngine.generateJoinCode(42);
      expect(code.length, 6);
      expect(RegExp(r'^[A-HJ-NP-Z2-9]+$').hasMatch(code), isTrue);
    });
  });
}
