import 'package:flutter_test/flutter_test.dart';
import 'package:ocl_study/domain/vocab/vocab_word.dart';

void main() {
  test('parseLines handles tab / space / comma separators', () {
    final words = VocabWord.parseLines('abandon\t포기하다\nanalyze 분석하다\nrun, 달리다\n\n   ');
    expect(words.length, 3);
    expect(words[0].term, 'abandon');
    expect(words[0].meaning, '포기하다');
    expect(words[1].term, 'analyze');
    expect(words[1].meaning, '분석하다');
    expect(words[2].term, 'run');
    expect(words[2].meaning, '달리다');
  });

  test('VocabResult computes wrong from weak list', () {
    final r = VocabResult(total: 10, correct: 8, weak: const [VocabWord('a', 'b'), VocabWord('c', 'd')], focusedMin: 5);
    expect(r.wrong, 2);
  });
}
