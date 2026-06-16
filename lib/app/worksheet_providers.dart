import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/firebase/worksheet_repository.dart';
import '../domain/worksheet/worksheet.dart';
import '../domain/worksheet/worksheet_question.dart';
import '../domain/worksheet/worksheet_submission.dart';
import 'account_providers.dart';

final worksheetRepositoryProvider = Provider<WorksheetRepository>((ref) => WorksheetRepository());

bool _signedOut(Ref ref) =>
    Firebase.apps.isEmpty || ref.watch(authStateProvider).value == null;

/// 한 교실의 학습지 목록(최신순).
final classroomWorksheetsProvider =
    StreamProvider.family<List<Worksheet>, String>((ref, classroomId) {
  if (_signedOut(ref)) return Stream.value(const []);
  return ref.watch(worksheetRepositoryProvider).watchWorksheetsByClassroom(classroomId);
});

/// 한 학습지의 문항(순서대로).
final worksheetQuestionsProvider =
    StreamProvider.family<List<WorksheetQuestion>, String>((ref, worksheetId) {
  if (_signedOut(ref)) return Stream.value(const []);
  return ref.watch(worksheetRepositoryProvider).watchQuestions(worksheetId);
});

/// 교사: 한 학습지의 제출 현황.
final worksheetSubmissionsProvider =
    StreamProvider.family<List<WorksheetSubmission>, String>((ref, worksheetId) {
  if (_signedOut(ref)) return Stream.value(const []);
  return ref.watch(worksheetRepositoryProvider).watchSubmissions(worksheetId);
});
