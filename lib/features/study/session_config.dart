import '../../domain/study/study_mode.dart';

/// The in-progress session setup carried from 공부 준비 into 공부 중.
class SessionConfig {
  final StudyMode mode;
  final String subject;
  final int goalMin;
  final int examDdays; // 시험 대비 모드: 시험까지 남은 일수
  const SessionConfig({
    required this.mode,
    required this.subject,
    required this.goalMin,
    this.examDdays = 14,
  });
}
