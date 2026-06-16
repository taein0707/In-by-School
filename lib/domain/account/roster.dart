// P8-3 — 업로드 명단에서 학생을 뽑아 자동 이메일을 부여하는 순수 로직.
//
// 흐름: 파일(텍스트/엑셀) → 원문 텍스트 → 이름 추출(Gemini 우선, 아래 휴리스틱 폴백)
//       → 이름 + 자동 이메일(로마자 핸들 + 순번) Preview.
//
// 모든 함수는 네트워크/플러그인 의존이 없어 단위 테스트가 가능하다.

/// Preview 한 줄 — 이름 + 자동 생성 이메일(임시 비밀번호는 교사가 일괄 지정).
class RosterEntry {
  final String name;
  final String email;
  const RosterEntry({required this.name, required this.email});

  RosterEntry copyWith({String? name, String? email}) =>
      RosterEntry(name: name ?? this.name, email: email ?? this.email);
}

class RosterBuilder {
  RosterBuilder._();

  static const String defaultDomain = 'school.local';

  /// 헤더로 흔히 쓰는 토큰(이 셀은 이름이 아님).
  static const Set<String> _headerTokens = {
    '이름', '성명', '학생', '학생명', '학생이름', '성함',
    '번호', '순번', '연번', '학번', 'no', 'no.', 'name', 'student', '#',
  };

  /// 자주 보이는 한국 성(姓) 로마자 표기.
  static const Map<String, String> _surname = {
    '김': 'kim', '이': 'lee', '박': 'park', '최': 'choi', '정': 'jung', '강': 'kang',
    '조': 'cho', '윤': 'yoon', '장': 'jang', '임': 'lim', '한': 'han', '오': 'oh',
    '서': 'seo', '신': 'shin', '권': 'kwon', '황': 'hwang', '안': 'ahn', '송': 'song',
    '전': 'jeon', '홍': 'hong', '문': 'moon', '양': 'yang', '손': 'son', '배': 'bae',
    '백': 'baek', '허': 'heo', '유': 'yoo', '남': 'nam', '심': 'shim', '하': 'ha',
    '곽': 'kwak', '성': 'sung', '차': 'cha', '주': 'joo', '우': 'woo', '구': 'koo',
    '민': 'min', '류': 'ryu', '나': 'na', '지': 'ji', '엄': 'eom', '채': 'chai',
    '원': 'won', '천': 'cheon', '방': 'bang', '공': 'kong', '현': 'hyun', '함': 'ham',
    '변': 'byun', '염': 'yeom', '여': 'yeo', '추': 'chu', '도': 'do', '소': 'so',
    '석': 'seok', '선': 'sun', '설': 'seol', '마': 'ma', '길': 'gil', '연': 'yeon',
    '위': 'wi', '표': 'pyo', '명': 'myung', '기': 'ki', '반': 'ban', '라': 'ra',
    '왕': 'wang', '금': 'keum', '옥': 'ok', '육': 'yook', '인': 'in', '맹': 'maeng',
  };

  // 초성 19개의 대표 로마자 첫 글자(ㅇ 은 중성으로 결정 → 빈 문자열).
  static const List<String> _choFirst = [
    'g', 'k', 'n', 'd', 't', 'r', 'm', 'b', 'p', 's', 's', '', 'j', 'j', 'c', 'k', 't', 'p', 'h',
  ];
  // 중성 21개 → ㅇ 초성일 때 쓰는 대표 로마자 첫 글자.
  static const List<String> _jungFirst = [
    'a', 'a', 'y', 'y', 'e', 'e', 'y', 'y', 'o', 'w', 'w', 'o', 'y', 'u', 'w', 'w', 'w', 'y', 'e', 'e', 'i',
  ];

  /// 한글 이름 → 이메일 핸들. 성은 표기 맵, 이름 음절은 첫 자음(또는 ㅇ→모음) 한 글자.
  /// 예) 김철수→kimcs · 이영희→leeyh · 박민수→parkms. 비한글은 영문/숫자만 추려 소문자화.
  static String romanizeHandle(String name) {
    final buf = StringBuffer();
    for (var i = 0; i < name.length; i++) {
      final ch = name[i];
      if (i == 0 && _surname.containsKey(ch)) {
        buf.write(_surname[ch]);
        continue;
      }
      final code = ch.codeUnitAt(0);
      if (code >= 0xAC00 && code <= 0xD7A3) {
        final s = code - 0xAC00;
        final cho = s ~/ 588;
        final jung = (s % 588) ~/ 28;
        final c = _choFirst[cho];
        buf.write(c.isNotEmpty ? c : (jung < _jungFirst.length ? _jungFirst[jung] : ''));
      } else if (RegExp(r'[A-Za-z0-9]').hasMatch(ch)) {
        buf.write(ch.toLowerCase());
      }
      // 그 외(공백/기호)는 건너뛴다.
    }
    return buf.toString();
  }

  /// 원문 텍스트에서 학생 이름만 추출하는 결정적 휴리스틱(Gemini 폴백).
  /// 한 줄을 셀(쉼표/탭/2칸+ 공백)로 나눠 헤더·순번을 제거하고 이름 후보를 고른다.
  static List<String> extractNames(String raw) {
    final out = <String>[];
    for (final line in raw.split(RegExp(r'[\r\n]+'))) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final cells = trimmed
          .split(RegExp(r'[,\t;]|\s{2,}'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      String? pick;
      for (final cell in cells) {
        // 앞에 붙은 순번("1.", "1)", "1 ")을 떼어낸다.
        final v = cell.replaceFirst(RegExp(r'^\d+\s*[.)\-]?\s*'), '').trim();
        if (v.isEmpty) continue;
        if (_headerTokens.contains(v.toLowerCase())) continue;
        if (RegExp(r'^\d+$').hasMatch(v)) continue; // 순수 숫자(순번)
        pick = v;
        if (RegExp(r'[가-힣]').hasMatch(v)) break; // 한글 이름을 우선
      }
      if (pick != null) out.add(pick);
    }
    return out;
  }

  /// 이름 목록 → 중복 없는 자동 이메일 부여.
  /// [handles] 가 주어지면(예: Gemini 로마자) 우선 사용하고, 비면 로컬 로마자 변환.
  static List<RosterEntry> build(
    List<String> names, {
    String domain = defaultDomain,
    List<String>? handles,
  }) {
    final clean = names.map((n) => n.trim()).where((n) => n.isNotEmpty).toList();
    final dom = domain.trim().isEmpty ? defaultDomain : domain.trim().toLowerCase();
    final width = clean.length < 100 ? 2 : clean.length.toString().length;
    final seen = <String>{};
    final out = <RosterEntry>[];
    for (var i = 0; i < clean.length; i++) {
      final fromGemini = (handles != null && i < handles.length) ? _slug(handles[i]) : '';
      final base = fromGemini.isNotEmpty ? fromGemini : romanizeHandle(clean[i]);
      final handle = base.isEmpty ? 'student' : base;
      var email = '$handle${(i + 1).toString().padLeft(width, '0')}@$dom';
      // 만일의 충돌(같은 핸들+순번)에 접미사를 붙여 유일성 보장.
      var bump = 0;
      while (seen.contains(email)) {
        bump++;
        email = '$handle${(i + 1).toString().padLeft(width, '0')}x$bump@$dom';
      }
      seen.add(email);
      out.add(RosterEntry(name: clean[i], email: email));
    }
    return out;
  }

  static String _slug(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}
