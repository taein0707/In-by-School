/// The study modes. OCL is not a stopwatch app — the mode shapes how the
/// session runs and what AI analysis it produces.
enum StudyMode { free, pomodoro, blank, memory, quiz, exam, vocab }

class StudyModeInfo {
  final StudyMode mode;
  final String name;
  final String tag;
  final String desc;
  final String forWhom;
  final bool launch; // included in the focused V2 launch

  const StudyModeInfo(this.mode, this.name, this.tag, this.desc, this.forWhom, {this.launch = false});

  static const Map<StudyMode, StudyModeInfo> _info = {
    StudyMode.free: StudyModeInfo(StudyMode.free, '자유 공부', '스톱워치',
        '원하는 만큼 공부해요. 일반 스톱워치 방식이에요.', '과제 · 독서 · 자유 학습', launch: true),
    StudyMode.pomodoro: StudyModeInfo(StudyMode.pomodoro, '포모도로', '25 + 5',
        '25분 공부하고 5분 쉬어요. 반복할 수 있어요.', '집중 유지', launch: true),
    StudyMode.blank: StudyModeInfo(StudyMode.blank, '백지복습', 'AI 분석',
        '공부한 뒤 배운 내용을 직접 써요. 토리가 이해도를 분석해요.', '개념 정리', launch: true),
    StudyMode.memory: StudyModeInfo(StudyMode.memory, '암기 모드', '복습 추천',
        '공부 후 복습 시점을 추천받아요. 망각곡선을 고려해요.', '암기 과목', launch: true),
    StudyMode.quiz: StudyModeInfo(StudyMode.quiz, '문제풀이', '정답률',
        '풀이 시간과 정답률을 기록해요. 취약 유형을 분석해요.', '기출 · 문제집', launch: true),
    StudyMode.exam: StudyModeInfo(StudyMode.exam, '시험 대비', 'D-day',
        '시험일까지 하루 목표를 토리가 제안해요.', '시험 일정', launch: true),
    StudyMode.vocab: StudyModeInfo(StudyMode.vocab, '영단어 외우기', 'OCR · 플래시카드',
        '사진이나 직접 입력으로 단어를 모아 플래시카드로 외워요.', '영어 단어', launch: true),
  };

  static StudyModeInfo of(StudyMode m) => _info[m]!;
  static List<StudyModeInfo> get launchModes =>
      _info.values.where((m) => m.launch).toList();
  static List<StudyModeInfo> get all => _info.values.toList();
}
