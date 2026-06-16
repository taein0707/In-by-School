import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../../domain/ai/blank_analysis.dart';
import '../../domain/aiquestion/ai_question_set.dart';
import '../../domain/assignment/assignment.dart' show Difficulty;
import '../../domain/lesson/lesson.dart';
import '../../domain/lesson/lesson_ai.dart';
import '../../domain/lesson/live.dart';
import '../../domain/report/study_report_template.dart' show StudySummary;

/// AI 기능(백지복습 분석 · 문제 생성) — Gemini 호출.
///
/// SECURITY(H-2): API 키는 더 이상 클라이언트에 두지 않는다. 호출은 Cloud Function
/// 프록시(functions/https/aiProxy)로 중계하며, 키는 Functions Secret 에 보관된다.
/// 프록시 URL 만 빌드 타임에 주입한다(비밀 아님):
///   flutter run --dart-define=AI_PROXY_URL=https://REGION-PROJECT.cloudfunctions.net/aiProxy
///
/// 프록시 URL 이 없거나 호출이 실패하면 항상 오프라인 폴백으로 떨어져 기능이 막히지 않는다.
class GeminiService {
  // 프록시 엔드포인트(있으면 우선 사용) — 비밀 아님.
  static const String _proxyUrl = String.fromEnvironment('AI_PROXY_URL');
  // Gemini API 키(프록시가 없을 때 직접 호출용) — 배포 시 소스에 키를 두지 않는다.
  // 필요하면 빌드 시 주입:  flutter build web --dart-define=GEMINI_API_KEY=...
  // 운영에서는 aiProxy 프록시(서버 키)로 두는 것을 권장.
  static const String _apiKey = String.fromEnvironment('GEMINI_API_KEY');
  // 직접 호출 시 사용할 모델(REST 모델 id). 'gemini-3.5-flash'는 존재하지 않아 2.5-flash 사용.
  // (override: --dart-define=GEMINI_MODEL=gemini-2.0-flash 등)
  static const String _model = String.fromEnvironment('GEMINI_MODEL', defaultValue: 'gemini-2.5-flash');

  // OpenAI(ChatGPT) API — 설정되면 Gemini 직접 호출보다 우선. 배포 시 소스에 키를 두지 않는다.
  // 필요하면 빌드 시 주입:  flutter build web --dart-define=OPENAI_API_KEY=...
  static const String _openAiKey = String.fromEnvironment('OPENAI_API_KEY');
  static const String _openAiModel = String.fromEnvironment('OPENAI_MODEL', defaultValue: 'gpt-5.4-mini');

  static const Duration _timeout = Duration(seconds: 25);

  /// 프록시 URL 또는 직접 키(Gemini/OpenAI) 중 하나라도 있으면 AI 사용 가능.
  static bool get hasAi => _proxyUrl.isNotEmpty || _apiKey.isNotEmpty || _openAiKey.isNotEmpty;

  /// 하위 호환 — 기존 호출부(`hasProxy`)가 그대로 동작하도록 둔다.
  static bool get hasProxy => hasAi;

  /// AI 호출 — 프록시가 있으면 프록시(서버 키), 없으면 API 키로 Gemini 직접 호출.
  /// 실패 시 null(호출부가 오프라인 폴백 처리).
  static Future<({String text, Map<String, dynamic> usage})?> _callProxy(
      String prompt, double temperature) async {
    if (_proxyUrl.isNotEmpty) {
      try {
        final token = await FirebaseAuth.instance.currentUser?.getIdToken();
        if (token != null) {
          final res = await http
              .post(
                Uri.parse(_proxyUrl),
                headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
                body: jsonEncode({'prompt': prompt, 'temperature': temperature, 'model': _model}),
              )
              .timeout(_timeout);
          if (res.statusCode == 200) {
            final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
            final text = body['text'] as String?;
            if (text != null) return (text: text, usage: (body['usage'] as Map?)?.cast<String, dynamic>() ?? const {});
          }
        }
      } catch (_) {/* 직접 호출로 폴백 */}
    }
    // OpenAI 키가 있으면 우선(임시), 없으면 Gemini 직접 호출.
    final viaOpenAi = await _callOpenAi(prompt, temperature);
    if (viaOpenAi != null) return viaOpenAi;
    return _callDirect(prompt, temperature);
  }

  /// OpenAI Chat Completions 직접 호출(임시). 응답이 ```json 코드펜스로 와도 벗겨 반환.
  static Future<({String text, Map<String, dynamic> usage})?> _callOpenAi(
      String prompt, double temperature) async {
    if (_openAiKey.isEmpty) return null;
    try {
      final res = await http
          .post(
            Uri.parse('https://api.openai.com/v1/chat/completions'),
            headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_openAiKey'},
            body: jsonEncode({
              'model': _openAiModel,
              'messages': [
                {'role': 'user', 'content': prompt}
              ],
              'temperature': temperature,
            }),
          )
          .timeout(_timeout);
      if (res.statusCode != 200) return null;
      final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final choices = body['choices'] as List?;
      if (choices == null || choices.isEmpty) return null;
      final content = ((choices.first as Map)['message'] as Map?)?['content'] as String?;
      if (content == null) return null;
      return (text: _unfence(content), usage: (body['usage'] as Map?)?.cast<String, dynamic>() ?? const {});
    } catch (_) {
      return null;
    }
  }

  /// Gemini 생성 API 직접 호출(API 키 사용). 응답이 ```json 코드펜스로 와도 벗겨 반환.
  static Future<({String text, Map<String, dynamic> usage})?> _callDirect(
      String prompt, double temperature) async {
    if (_apiKey.isEmpty) return null;
    try {
      final uri = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$_apiKey');
      final res = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': prompt}
                  ]
                }
              ],
              'generationConfig': {'temperature': temperature},
            }),
          )
          .timeout(_timeout);
      if (res.statusCode != 200) return null;
      final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final cands = body['candidates'] as List?;
      if (cands == null || cands.isEmpty) return null;
      final parts = ((cands.first as Map)['content'] as Map?)?['parts'] as List?;
      final raw = (parts != null && parts.isNotEmpty) ? (parts.first as Map)['text'] as String? : null;
      if (raw == null) return null;
      return (text: _unfence(raw), usage: (body['usageMetadata'] as Map?)?.cast<String, dynamic>() ?? const {});
    } catch (_) {
      return null;
    }
  }

  /// ```json ... ``` 코드펜스를 벗겨 JSON 파서가 읽을 수 있게 한다(평문엔 영향 없음).
  static String _unfence(String t) {
    var s = t.trim();
    if (s.startsWith('```')) {
      s = s.replaceFirst(RegExp(r'^```[a-zA-Z]*\s*'), '');
      if (s.endsWith('```')) s = s.substring(0, s.length - 3);
    }
    return s.trim();
  }

  static Future<BlankAnalysis> analyzeBlankReview({
    required String subject,
    required String text,
  }) async {
    if (!hasProxy || text.trim().length < 4) return BlankAnalysis.heuristic(text);
    final r = await _callProxy(_prompt(subject, text), 0.3);
    if (r == null) return BlankAnalysis.heuristic(text);
    try {
      final parsed = jsonDecode(r.text) as Map<String, dynamic>;
      return BlankAnalysis.fromJson(parsed);
    } catch (_) {
      return BlankAnalysis.heuristic(text);
    }
  }

  static String _prompt(String subject, String text) => '''
당신은 학습 동반자 "토리"입니다. 학생이 "$subject" 과목을 공부한 뒤,
기억나는 내용을 백지에 복습한 글입니다. 점수보다 따뜻하고 구체적인 서술 피드백을 주세요.
해요체, 이모지 없이.

학생의 백지복습:
"""
$text
"""

다음 JSON 형식으로만 답하세요(다른 텍스트 금지):
{
  "understanding": 0부터 100 사이 정수 (이해도),
  "understood": ["학생이 잘 이해하고 정확히 설명한 개념 1~3개, 각각 짧게"],
  "missing": ["빠지거나 약한/틀린 개념 1~3개, 각각 한 문장"],
  "accuracy": "설명의 정확성에 대한 한 문장 피드백",
  "review": "언제 무엇을 다시 복습하면 좋을지 한 문장 추천",
  "nextStudy": "다음에 무엇을 공부하면 좋을지 토리의 제안 한 문장"
}
''';

  // =====================================================================
  // Phase S — AI 스터디 플래너(학습 기록 초안)
  // =====================================================================

  /// 오늘 학습 요약(StudySummary)으로 학습 기록 초안 문장을 생성한다.
  /// 프록시 미설정/실패 시 null 을 반환해 호출부가 로컬 템플릿으로 폴백하게 한다.
  static Future<String?> generateStudyReportDraft(StudySummary s) async {
    if (!hasProxy) return null;
    try {
      final r = await _callProxy(_reportPrompt(s), 0.5);
      final text = r?.text.trim();
      return (text == null || text.isEmpty) ? null : text;
    } catch (_) {
      return null;
    }
  }

  static String _reportPrompt(StudySummary s) {
    final facts = <String>[
      '오늘 공부 시간: ${s.studyMinutes}분',
      if (s.subjects.isNotEmpty) '과목: ${s.subjects.join(', ')}',
      if (s.didBlankReview) '백지복습 진행함',
      if (s.reviewedCards > 0) '복습한 플래시카드: ${s.reviewedCards}장',
      if (s.quizAccuracy != null) '문제 정답률: ${s.quizAccuracy}%',
      if (s.assignmentsDone > 0) '완료한 숙제: ${s.assignmentsDone}개',
    ].join('\n');
    return '''
당신은 학생의 하루 학습 기록(스터디 플래너) 초안을 작성하는 도우미입니다.
아래 학습 데이터를 바탕으로 4문장 내외의 자연스러운 한국어 서술형 기록을 쓰세요.
- 사실에 근거하고, 과장하지 마세요.
- 마지막에 내일 학습 계획을 한 문장 포함하세요.
- 평서문(하였다체), 이모지/머리말/따옴표 없이 본문만 출력하세요.

학습 데이터:
$facts
''';
  }

  // =====================================================================
  // P10 — AI 자동 수업 생성 / AI 수정
  // =====================================================================

  /// 주제·학년·페이지수·유형·난이도로 수업 슬라이드를 생성한다.
  /// 프록시 미설정/실패 시 결정적 휴리스틱 골격으로 폴백해 항상 슬라이드를 돌려준다.
  static Future<List<LessonSlide>> generateLesson({
    required String topic,
    required String grade,
    required int pageCount,
    required List<LessonSlideType> types,
    required String difficulty,
  }) async {
    if (hasProxy) {
      try {
        final r = await _callProxy(_lessonGenPrompt(topic, grade, pageCount, types, difficulty), 0.6);
        if (r != null) {
          final parsed = LessonAi.parseSlides(jsonDecode(r.text));
          if (parsed.isNotEmpty) return parsed;
        }
      } catch (_) {/* 폴백 */}
    }
    return LessonAi.heuristic(topic: topic, types: types, pageCount: pageCount);
  }

  /// 자연어 지시로 기존 슬라이드를 수정한다(예: "퀴즈를 3개 더 추가해줘").
  /// 프록시 미설정/실패 시 null → 호출부가 "AI 연결 필요"를 안내한다.
  static Future<List<LessonSlide>?> editLesson({
    required List<LessonSlide> slides,
    required String instruction,
  }) async {
    if (!hasProxy || instruction.trim().isEmpty) return null;
    try {
      final r = await _callProxy(_lessonEditPrompt(slides, instruction), 0.5);
      if (r == null) return null;
      final parsed = LessonAi.parseSlides(jsonDecode(r.text));
      return parsed.isEmpty ? null : parsed;
    } catch (_) {
      return null;
    }
  }

  /// 학생 답변 묶음을 한두 문장으로 요약한다(P10-2). 프록시 미설정/실패 시 키워드 폴백.
  static Future<String> summarizeResponses(List<String> answers, {String topic = ''}) async {
    final clean = answers.map((a) => a.trim()).where((a) => a.isNotEmpty).toList();
    if (clean.isEmpty) return LiveAggregate.heuristicSummary(const []);
    if (hasProxy) {
      try {
        final joined = clean.take(60).map((a) => '- $a').join('\n');
        final prompt = '''
다음은 학생들이 ${topic.isEmpty ? '한 질문' : '"$topic"'} 에 답한 내용입니다(${clean.length}개).
공통된 생각과 키워드를 2~3문장으로 따뜻하게 요약하세요. 해요체, 머리말/이모지 없이 본문만.

$joined
''';
        final r = await _callProxy(prompt, 0.4);
        final text = r?.text.trim();
        if (text != null && text.isNotEmpty) return text;
      } catch (_) {/* 폴백 */}
    }
    return LiveAggregate.heuristicSummary(clean);
  }

  static String _typeMenu(List<LessonSlideType> types) {
    final list = types.isEmpty ? LessonSlideType.values : types;
    return list.map((t) => '${t.name}(${t.label})').join(', ');
  }

  static String _slideSchema() => '''
각 슬라이드 객체:
- "type": 아래 허용 type 이름 중 하나(영문 enum 이름)
- "text": 제목/설명/질문/문제/안내 문구
- "choices": 객관식·OX·순서·투표·빙고 등 보기 배열(없으면 [])
- "answer": 정답(없으면 "")
- "number": 숫자 파라미터(카운트다운 초·모둠 인원·빙고 N 등, 없으면 0)
- "mediaUrl": 이미지/영상/문서 URL(없으면 "")''';

  static String _lessonGenPrompt(
      String topic, String grade, int pageCount, List<LessonSlideType> types, String difficulty) {
    return '''
당신은 한국 학교 수업을 설계하는 도우미입니다. 아래 조건으로 슬라이드 수업을 만드세요.
주제: "$topic"
학년: "$grade"
난이도: "$difficulty"
슬라이드 수: $pageCount
사용할 수 있는 슬라이드 type(영문 이름): ${_typeMenu(types)}
규칙:
- 첫 슬라이드는 type "title" 로 수업 제목.
- 요청된 유형을 골고루 활용하고, 학년·난이도에 맞춰 쉬운 말로.
- 정확히 $pageCount 개의 슬라이드.
${_slideSchema()}

다음 JSON 형식으로만 답하세요(다른 텍스트 금지):
{ "slides": [ { "type": "...", "text": "...", "choices": [], "answer": "", "number": 0, "mediaUrl": "" } ] }
''';
  }

  static String _lessonEditPrompt(List<LessonSlide> slides, String instruction) {
    final current = slides
        .asMap()
        .entries
        .map((e) => '${e.key + 1}. [${e.value.type.name}] ${e.value.text}')
        .join('\n');
    return '''
현재 수업 슬라이드:
$current

교사의 수정 요청: "$instruction"

요청을 반영한 **전체 슬라이드 목록**을 다시 만들어 주세요(추가/수정/삭제 반영).
${_slideSchema()}

다음 JSON 형식으로만 답하세요(다른 텍스트 금지):
{ "slides": [ { "type": "...", "text": "...", "choices": [], "answer": "", "number": 0, "mediaUrl": "" } ] }
''';
  }

  // =====================================================================
  // P8-3 — 명단 텍스트에서 학생 이름 자동 추출
  // =====================================================================

  /// 업로드 명단 원문에서 학생 이름(+로마자 이메일 핸들)을 추출한다.
  /// 프록시 미설정/실패/파싱 실패 시 null → 호출부가 로컬 휴리스틱으로 폴백한다.
  static Future<List<({String name, String handle})>?> extractStudentRoster(String raw) async {
    if (!hasProxy || raw.trim().isEmpty) return null;
    try {
      final r = await _callProxy(_rosterPrompt(raw), 0.1);
      if (r == null) return null;
      final parsed = jsonDecode(r.text) as Map<String, dynamic>;
      final list = (parsed['students'] as List?) ?? const [];
      final out = <({String name, String handle})>[];
      for (final e in list) {
        final m = (e as Map).cast<String, dynamic>();
        final name = (m['name'] as String? ?? '').trim();
        final handle = (m['handle'] as String? ?? '').trim();
        if (name.isNotEmpty) out.add((name: name, handle: handle));
      }
      return out.isEmpty ? null : out;
    } catch (_) {
      return null;
    }
  }

  static String _rosterPrompt(String raw) => '''
다음은 교사가 업로드한 학생 명단 원문입니다(엑셀/CSV/텍스트에서 추출).
헤더(이름/번호 등)와 순번 숫자는 무시하고 실제 학생 이름만 골라내세요.
각 이름마다 이메일에 쓸 로마자 핸들(소문자 영문자만, 성+이름 이니셜 형태, 예: 김철수→kimcs)을 함께 만드세요.

원문:
"""
$raw
"""

다음 JSON 형식으로만 답하세요(다른 텍스트 금지):
{
  "students": [
    { "name": "학생 이름", "handle": "로마자핸들" }
  ]
}
''';

  // =====================================================================
  // Phase 3 — AI 문제 생성
  // =====================================================================

  /// 주제(또는 플래시카드 카드) 기반으로 문제를 생성한다.
  /// 실패(키 없음/타임아웃/파싱 실패)하면 항상 결정적 오프라인 폴백을 반환해
  /// 기능이 절대 막히지 않게 한다. 토큰 사용량을 함께 반환해 비용을 추적한다.
  static Future<QuestionGenResult> generateQuestions({
    required String topic,
    required Difficulty difficulty,
    required int count,
    required Set<QuestionType> types,
    List<QuestionCard> cards = const [],
  }) async {
    final n = count.clamp(1, 20);
    if (!hasProxy) {
      return _fallbackQuestions(topic: topic, count: n, types: types, cards: cards);
    }
    try {
      final r = await _callProxy(_questionPrompt(topic, difficulty, n, types, cards), 0.4);
      if (r == null) {
        return _fallbackQuestions(topic: topic, count: n, types: types, cards: cards);
      }
      final parsed = jsonDecode(r.text) as Map<String, dynamic>;
      final list = (parsed['questions'] as List?) ?? const [];
      final questions = <AiQuestion>[];
      for (var i = 0; i < list.length; i++) {
        final m = (list[i] as Map).cast<String, dynamic>();
        final q = AiQuestion(
          type: QuestionType.fromName(m['type'] as String?),
          prompt: (m['prompt'] as String? ?? '').trim(),
          choices: (m['choices'] as List?)?.map((e) => e.toString()).toList() ?? const [],
          answer: (m['answer'] as String? ?? '').trim(),
          explanation: (m['explanation'] as String? ?? '').trim(),
          order: i,
        );
        if (q.prompt.isNotEmpty && q.answer.isNotEmpty) questions.add(q);
      }
      if (questions.isEmpty) {
        return _fallbackQuestions(topic: topic, count: n, types: types, cards: cards);
      }
      final usage = r.usage;
      return QuestionGenResult(
        questions: questions,
        fallbackUsed: false,
        model: _model,
        promptTokens: (usage['promptTokenCount'] as num?)?.toInt() ?? 0,
        candidatesTokens: (usage['candidatesTokenCount'] as num?)?.toInt() ?? 0,
        totalTokens: (usage['totalTokenCount'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return _fallbackQuestions(topic: topic, count: n, types: types, cards: cards);
    }
  }

  static String _questionPrompt(
      String topic, Difficulty difficulty, int count, Set<QuestionType> types, List<QuestionCard> cards) {
    final typeList = types.map((t) => t.name).join(', ');
    final source = cards.isEmpty
        ? '주제: "$topic"'
        : '아래 단어/개념 카드(앞=front, 뒤=back)를 바탕으로 출제하세요.\n'
            '${cards.map((c) => '- ${c.front} / ${c.back}${c.example.isNotEmpty ? ' (예: ${c.example})' : ''}').join('\n')}';
    return '''
당신은 한국 학생을 가르치는 출제 도우미입니다. 다음 자료로 학습 문제 $count개를 만드세요.
$source
난이도: ${difficulty.label}
허용 유형(type): $typeList
규칙:
- multipleChoice: choices 4개(정답 1 + 오답 3), answer 는 정답 choice 와 정확히 같은 문자열.
- shortAnswer: 한두 단어로 답할 수 있게. answer 는 채점용 표준 정답.
- fillBlank: prompt 안에 빈칸을 "____"(밑줄 4개)로 표기, answer 는 빈칸에 들어갈 말.
- 각 문제에 짧은 해설(explanation).
- 모든 문제에 answer 를 반드시 채울 것(자동 채점용).

다음 JSON 형식으로만 답하세요(다른 텍스트 금지):
{
  "questions": [
    {
      "type": "multipleChoice | shortAnswer | fillBlank",
      "prompt": "문제 지문",
      "choices": ["객관식일 때만 4개, 그 외 빈 배열"],
      "answer": "정답",
      "explanation": "짧은 해설"
    }
  ]
}
''';
  }

  /// 결정적 오프라인 폴백 — 카드가 있으면 카드에서, 없으면 주제 골격을 만든다.
  static QuestionGenResult _fallbackQuestions({
    required String topic,
    required int count,
    required Set<QuestionType> types,
    required List<QuestionCard> cards,
  }) {
    final order = types.isEmpty ? [QuestionType.shortAnswer] : types.toList();
    final out = <AiQuestion>[];

    if (cards.isNotEmpty) {
      final backs = cards.map((c) => c.back).where((b) => b.trim().isNotEmpty).toList();
      for (var i = 0; i < cards.length && out.length < count; i++) {
        final card = cards[i];
        if (card.front.trim().isEmpty || card.back.trim().isEmpty) continue;
        final type = order[i % order.length];
        switch (type) {
          case QuestionType.multipleChoice:
            final distractors = backs.where((b) => b != card.back).toList();
            final picks = <String>[];
            for (var k = 0; k < distractors.length && picks.length < 3; k++) {
              final cand = distractors[(i + k) % distractors.length];
              if (!picks.contains(cand) && cand != card.back) picks.add(cand);
            }
            while (picks.length < 3) {
              picks.add('보기 ${picks.length + 1}');
            }
            final choices = [card.back, ...picks];
            // 정답 위치를 카드마다 회전(항상 1번이 정답이 되지 않게).
            final rot = i % choices.length;
            final rotated = [...choices.sublist(rot), ...choices.sublist(0, rot)];
            out.add(AiQuestion(
              type: type,
              prompt: '‘${card.front}’의 뜻으로 알맞은 것은?',
              choices: rotated,
              answer: card.back,
              explanation: '${card.front} = ${card.back}',
              order: out.length,
            ));
          case QuestionType.shortAnswer:
            out.add(AiQuestion(
              type: type,
              prompt: '‘${card.front}’의 뜻을 쓰세요.',
              answer: card.back,
              explanation: '${card.front} = ${card.back}',
              order: out.length,
            ));
          case QuestionType.fillBlank:
            final hasEx = card.example.isNotEmpty && card.example.contains(card.front);
            out.add(AiQuestion(
              type: type,
              prompt: hasEx ? card.example.replaceAll(card.front, '____') : '${card.front} : ____',
              answer: hasEx ? card.front : card.back,
              explanation: '${card.front} = ${card.back}',
              order: out.length,
            ));
        }
      }
    }

    // 카드가 없거나 부족하면 주제 기반 골격(정답은 선생님이 보완)으로 채운다.
    var idx = out.length;
    while (out.length < count) {
      final type = order[idx % order.length];
      out.add(AiQuestion(
        type: type,
        prompt: type == QuestionType.fillBlank
            ? '$topic 의 핵심 개념은 "____" 이다.'
            : '$topic 관련 문제 ${idx + 1}',
        choices: type == QuestionType.multipleChoice ? const ['보기 1', '보기 2', '보기 3', '보기 4'] : const [],
        answer: '',
        explanation: '',
        order: out.length,
      ));
      idx++;
    }

    return QuestionGenResult(
      questions: out.take(count).toList(),
      fallbackUsed: true,
      model: '',
      promptTokens: 0,
      candidatesTokens: 0,
      totalTokens: 0,
    );
  }
}

/// 문제 생성 입력 — 플래시카드 카드의 최소 정보.
class QuestionCard {
  final String front;
  final String back;
  final String example;
  const QuestionCard({required this.front, required this.back, this.example = ''});
}

/// 문제 생성 결과 + 토큰 사용량(비용 추적).
class QuestionGenResult {
  final List<AiQuestion> questions;
  final bool fallbackUsed;
  final String model;
  final int promptTokens;
  final int candidatesTokens;
  final int totalTokens;
  const QuestionGenResult({
    required this.questions,
    required this.fallbackUsed,
    required this.model,
    required this.promptTokens,
    required this.candidatesTokens,
    required this.totalTokens,
  });
}
