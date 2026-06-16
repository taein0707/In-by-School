import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/firebase/study_report_repository.dart';
import '../domain/report/study_report.dart';
import 'account_providers.dart';

final studyReportRepositoryProvider =
    Provider<StudyReportRepository>((ref) => StudyReportRepository());

/// 미인증(로그아웃/전환)이면 빈 스트림 — stale 리스너 permission-denied 방지(P2-1).
bool _signedOut(Ref ref) =>
    Firebase.apps.isEmpty || ref.watch(authStateProvider).value == null;

/// 학생: 내가 작성/제출한 학습 기록(최신순).
final myReportsProvider = StreamProvider<List<StudyReport>>((ref) {
  if (_signedOut(ref)) return Stream.value(const []);
  return ref.watch(studyReportRepositoryProvider).watchMyReports();
});

/// 선생님: 나에게 제출된 학습 기록(최신 제출순).
final teacherReportsProvider = StreamProvider<List<StudyReport>>((ref) {
  if (_signedOut(ref)) return Stream.value(const []);
  return ref.watch(studyReportRepositoryProvider).watchTeacherReports();
});
