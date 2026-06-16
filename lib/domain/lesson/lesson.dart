// 슬라이드 기반 수업(P9-2 / P10) — 교사가 만드는 수업 자료.
//
//   lessons/{id}            — 수업(슬라이드 배열을 문서 안에 보관)
//   lessons/{id}/ideas/{p}  — 실시간 아이디어보드 포스트잇(학생 제출)
//   lessonResponses/{id}    — 학생 응답(질문/퀴즈/입력형)  [P10 실시간 기반]
//   lessonSessions/{id}     — Teacher Live Mode 세션 상태  [P10 실시간 기반]
//
// teacherUid 를 비정규화해 보안규칙이 get() 없이 평가한다.

/// 슬라이드 카테고리(추가 피커 그룹).
enum SlideCategory {
  info, // 정보형
  input, // 학생 입력형
  live, // 실시간 참여형
  flow, // 수업 진행형
  game, // 게임형
  wrap; // 마무리

  String get label => switch (this) {
        SlideCategory.info => '정보형',
        SlideCategory.input => '학생 입력형',
        SlideCategory.live => '실시간 참여형',
        SlideCategory.flow => '수업 진행형',
        SlideCategory.game => '게임형',
        SlideCategory.wrap => '마무리',
      };
}

/// 슬라이드 30+종(P10). 기존 5종(title/question/ideaBoard/timer/quiz)은 호환 유지.
enum LessonSlideType {
  // A. 정보형
  title,
  description,
  image,
  video,
  document,
  // B. 학생 입력형
  shortAnswer,
  longAnswer,
  keyword,
  multipleChoice,
  multiSelect,
  ox,
  ordering,
  fillBlank,
  question, // 질문(+답변 기록) — 기존
  // C. 실시간 참여형
  ideaBoard, // ⭐ 기존
  wordCloud,
  livePoll,
  reactions,
  anonymousQuestion,
  liveDrawing,
  // D. 수업 진행형
  timer, // 기존
  countdown,
  randomPicker,
  randomGroup,
  randomSeat,
  // E. 게임형
  bingo,
  crossword,
  quizBattle,
  quiz, // 기존(일반 퀴즈)
  // F. 마무리
  exitTicket,
  aiSummary,
  studentSlide;

  String get label => switch (this) {
        title => '제목',
        description => '설명',
        image => '이미지',
        video => '영상',
        document => 'PDF/문서',
        shortAnswer => '짧은 답변',
        longAnswer => '긴 답변',
        keyword => '키워드 입력',
        multipleChoice => '객관식',
        multiSelect => '복수선택',
        ox => 'OX',
        ordering => '순서 배열',
        fillBlank => '빈칸 채우기',
        question => '질문',
        ideaBoard => '아이디어 보드',
        wordCloud => '워드 클라우드',
        livePoll => '실시간 투표',
        reactions => '좋아요',
        anonymousQuestion => '익명 질문',
        liveDrawing => '실시간 그림판',
        timer => '타이머',
        countdown => '카운트다운',
        randomPicker => '발표 학생 추첨',
        randomGroup => '랜덤 모둠',
        randomSeat => '랜덤 자리 배치',
        bingo => '빙고',
        crossword => '가로세로 퍼즐',
        quizBattle => '퀴즈 배틀',
        quiz => '퀴즈',
        exitTicket => 'Exit Ticket',
        aiSummary => 'AI 요약',
        studentSlide => '학생 답변 슬라이드',
      };

  SlideCategory get category => switch (this) {
        title || description || image || video || document => SlideCategory.info,
        shortAnswer || longAnswer || keyword || multipleChoice || multiSelect || ox || ordering || fillBlank || question =>
          SlideCategory.input,
        ideaBoard || wordCloud || livePoll || reactions || anonymousQuestion || liveDrawing => SlideCategory.live,
        timer || countdown || randomPicker || randomGroup || randomSeat => SlideCategory.flow,
        bingo || crossword || quizBattle || quiz => SlideCategory.game,
        exitTicket || aiSummary || studentSlide => SlideCategory.wrap,
      };

  /// 미디어 URL 을 쓰는 유형(이미지/영상/문서).
  bool get hasMedia => this == image || this == video || this == document;

  /// 보기/정답을 쓰는 유형(객관식·OX·순서·빈칸·투표·퀴즈류).
  bool get hasChoices =>
      this == multipleChoice ||
      this == multiSelect ||
      this == ox ||
      this == ordering ||
      this == fillBlank ||
      this == livePoll ||
      this == quiz ||
      this == quizBattle;

  /// 숫자 파라미터를 쓰는 유형. (timer 는 분→초로 timerSeconds 사용, 그 외는 number)
  bool get hasNumber => this == timer || this == countdown || this == randomGroup || this == bingo;

  String get numberUnit => switch (this) {
        timer => '분',
        countdown => '초',
        randomGroup => '명/모둠',
        bingo => 'N칸',
        _ => '',
      };

  static LessonSlideType fromName(String? s) =>
      values.firstWhere((e) => e.name == s, orElse: () => LessonSlideType.title);
}

/// 퀴즈 슬라이드 유형.
enum QuizKind {
  multipleChoice,
  ox,
  shortAnswer;

  String get label => switch (this) {
        QuizKind.multipleChoice => '객관식',
        QuizKind.ox => 'OX',
        QuizKind.shortAnswer => '단답형',
      };

  static QuizKind fromName(String? s) =>
      values.firstWhere((e) => e.name == s, orElse: () => QuizKind.multipleChoice);
}

class LessonSlide {
  final String id;
  final LessonSlideType type;
  final String text; // 제목/설명/질문/안내/퀴즈 문제 등
  final String mediaUrl; // 이미지/영상/문서 URL
  final int timerSeconds; // timer 전용(초)
  final int number; // countdown(초)/randomGroup(명)/bingo(N) 등 일반 숫자 파라미터
  final QuizKind quizKind; // 퀴즈류 채점 유형
  final List<String> choices; // 보기/순서 항목/투표 항목/빙고 단어
  final String answer; // 정답

  const LessonSlide({
    required this.id,
    required this.type,
    this.text = '',
    this.mediaUrl = '',
    this.timerSeconds = 300,
    this.number = 0,
    this.quizKind = QuizKind.multipleChoice,
    this.choices = const [],
    this.answer = '',
  });

  LessonSlide copyWith({
    LessonSlideType? type,
    String? text,
    String? mediaUrl,
    int? timerSeconds,
    int? number,
    QuizKind? quizKind,
    List<String>? choices,
    String? answer,
  }) =>
      LessonSlide(
        id: id,
        type: type ?? this.type,
        text: text ?? this.text,
        mediaUrl: mediaUrl ?? this.mediaUrl,
        timerSeconds: timerSeconds ?? this.timerSeconds,
        number: number ?? this.number,
        quizKind: quizKind ?? this.quizKind,
        choices: choices ?? this.choices,
        answer: answer ?? this.answer,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.name,
        'text': text,
        'mediaUrl': mediaUrl,
        'timerSeconds': timerSeconds,
        'number': number,
        'quizKind': quizKind.name,
        'choices': choices,
        'answer': answer,
      };

  factory LessonSlide.fromMap(Map<String, dynamic> m) => LessonSlide(
        id: m['id'] as String? ?? '',
        type: LessonSlideType.fromName(m['type'] as String?),
        text: m['text'] as String? ?? '',
        mediaUrl: m['mediaUrl'] as String? ?? '',
        timerSeconds: (m['timerSeconds'] as num?)?.toInt() ?? 300,
        number: (m['number'] as num?)?.toInt() ?? 0,
        quizKind: QuizKind.fromName(m['quizKind'] as String?),
        choices: (m['choices'] as List?)?.whereType<String>().toList() ?? const [],
        answer: m['answer'] as String? ?? '',
      );
}

class Lesson {
  final String id;
  final String teacherUid;
  final String classroomId; // 비어 있으면 특정 교실 비귀속
  final String classroomName;
  final String title;
  final List<LessonSlide> slides;
  final DateTime? createdAt;

  const Lesson({
    required this.id,
    required this.teacherUid,
    this.classroomId = '',
    this.classroomName = '',
    this.title = '',
    this.slides = const [],
    this.createdAt,
  });

  Lesson copyWith({String? title, List<LessonSlide>? slides}) => Lesson(
        id: id,
        teacherUid: teacherUid,
        classroomId: classroomId,
        classroomName: classroomName,
        title: title ?? this.title,
        slides: slides ?? this.slides,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'teacherUid': teacherUid,
        'classroomId': classroomId,
        'classroomName': classroomName,
        'title': title,
        'slides': slides.map((s) => s.toMap()).toList(),
        'createdAt': createdAt?.toIso8601String(),
      };

  factory Lesson.fromMap(Map<String, dynamic> m) => Lesson(
        id: m['id'] as String? ?? '',
        teacherUid: m['teacherUid'] as String? ?? '',
        classroomId: m['classroomId'] as String? ?? '',
        classroomName: m['classroomName'] as String? ?? '',
        title: m['title'] as String? ?? '',
        slides: (m['slides'] as List?)
                ?.whereType<Map>()
                .map((e) => LessonSlide.fromMap(e.cast<String, dynamic>()))
                .toList() ??
            const [],
        createdAt: (m['createdAt'] as String?) != null ? DateTime.tryParse(m['createdAt'] as String) : null,
      );
}
