/// A single flashcard word pair.
class VocabWord {
  final String term; // 앞면 (영단어)
  final String meaning; // 뒷면 (뜻)
  const VocabWord(this.term, this.meaning);

  /// Parse typed/recognized text into word pairs. Accepts tab / comma /
  /// "english 뜻" / 2+ spaces separators, one pair per line.
  static List<VocabWord> parseLines(String text) {
    final out = <VocabWord>[];
    for (final raw in text.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      List<String>? parts;
      if (line.contains('\t')) {
        parts = line.split('\t');
      } else if (line.contains(',')) {
        parts = line.split(',');
      } else {
        final m = RegExp(r'^(.+?)\s+([가-힣].*)$').firstMatch(line); // 영단어 + 한글 뜻
        if (m != null) {
          parts = [m.group(1)!, m.group(2)!];
        } else {
          final p = line.split(RegExp(r'\s{2,}'));
          if (p.length >= 2) parts = p;
        }
      }
      if (parts != null && parts.length >= 2) {
        final t = parts[0].trim();
        final mn = parts.sublist(1).join(' ').trim();
        if (t.isNotEmpty && mn.isNotEmpty) out.add(VocabWord(t, mn));
      }
    }
    return out;
  }
}

/// Outcome of a flashcard session.
class VocabResult {
  final int total;
  final int correct;
  final List<VocabWord> weak; // 틀린/모르는 단어
  final int focusedMin;
  const VocabResult({required this.total, required this.correct, required this.weak, required this.focusedMin});
  int get wrong => weak.length;
}
