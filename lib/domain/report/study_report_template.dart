/// 하루 학습을 요약한 입력(자동 기록 생성용). 기존 데이터(세션·복습·숙제)에서
/// 모아 만든 스냅샷이며, AI 프롬프트와 로컬 템플릿이 공유한다.
class StudySummary {
  final int studyMinutes; // 오늘 집중 분
  final List<String> subjects; // 오늘 학습한 과목
  final int sessionCount; // 오늘 세션 수
  final bool didBlankReview; // 백지복습 진행 여부
  final int? quizAccuracy; // 문제 정답률(0~100), 없으면 null
  final int reviewedCards; // 오늘 복습한 카드 수(SRS)
  final int assignmentsDone; // 완료한 숙제 수

  const StudySummary({
    this.studyMinutes = 0,
    this.subjects = const [],
    this.sessionCount = 0,
    this.didBlankReview = false,
    this.quizAccuracy,
    this.reviewedCards = 0,
    this.assignmentsDone = 0,
  });

  String get primarySubject => subjects.isNotEmpty ? subjects.first : '학습';

  bool get isEmpty =>
      studyMinutes == 0 &&
      reviewedCards == 0 &&
      assignmentsDone == 0 &&
      quizAccuracy == null &&
      !didBlankReview &&
      sessionCount == 0;
}

/// AI 실패/미설정 시 사용하는 결정적 로컬 학습 기록 초안 생성기.
class StudyReportTemplate {
  StudyReportTemplate._();

  static String compose(StudySummary s) {
    if (s.isEmpty) {
      return '오늘은 가볍게 학습 계획을 점검하였다.\n\n'
          '내일은 목표를 정해 본격적으로 학습할 예정이다.';
    }

    final subjectPhrase = s.subjects.isEmpty ? '' : '${s.subjects.join('·')} ';

    final activities = <String>[];
    if (s.didBlankReview) activities.add('백지복습');
    if (s.reviewedCards > 0) activities.add('플래시카드 복습');
    if (s.quizAccuracy != null) activities.add('문제 풀이');
    final activityPhrase = activities.isEmpty ? '집중 학습' : activities.join('과(와) ');

    final details = <String>[];
    if (s.reviewedCards > 0) details.add('복습 카드 ${s.reviewedCards}장을 학습하였다');
    if (s.quizAccuracy != null) details.add('문제 정답률은 ${s.quizAccuracy}%였다');
    if (s.assignmentsDone > 0) details.add('숙제 ${s.assignmentsDone}개를 완료하였다');
    final detailPhrase = details.isEmpty ? '꾸준히 집중하였다' : details.join(', ');

    final String weak;
    if (s.quizAccuracy != null && s.quizAccuracy! < 70) {
      weak = '오답이 있어 추가 복습이 필요하다고 판단된다.';
    } else if (s.reviewedCards > 0) {
      weak = '부족한 부분은 반복 복습으로 보완할 계획이다.';
    } else {
      weak = '전반적으로 무난하게 학습하였다.';
    }

    final String plan;
    if (s.quizAccuracy != null && s.quizAccuracy! < 70) {
      plan = '오답과 취약한 부분을 다시 학습할';
    } else if (s.reviewedCards > 0) {
      plan = '오늘 학습한 내용을 다시 복습할';
    } else {
      plan = '새로운 내용을 이어서 학습할';
    }

    return '오늘은 $subjectPhrase$activityPhrase을(를) 진행하였다.\n\n'
        '총 ${s.studyMinutes}분 동안 학습하였으며, $detailPhrase.\n\n'
        '$weak\n\n'
        '내일은 $plan 예정이다.';
  }
}
