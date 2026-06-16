import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/firebase/bingo_repository.dart';
import '../data/firebase/crossword_repository.dart';
import '../data/firebase/quiz_repository.dart';
import '../domain/engagement/bingo_game.dart';
import '../domain/engagement/crossword_set.dart';
import '../domain/engagement/quiz_competition.dart';
import 'account_providers.dart';

bool _signedOut(Ref ref) =>
    Firebase.apps.isEmpty || ref.watch(authStateProvider).value == null;

// ---- 빙고(P4-1) ----
final bingoRepositoryProvider = Provider<BingoRepository>((ref) => BingoRepository());

/// 한 교실의 빙고 게임 목록(최신순).
final classroomBingosProvider =
    StreamProvider.family<List<BingoGame>, String>((ref, classroomId) {
  if (_signedOut(ref)) return Stream.value(const []);
  return ref.watch(bingoRepositoryProvider).watchBingosByClassroom(classroomId);
});

/// 단일 빙고 게임(실시간).
final bingoGameProvider =
    StreamProvider.family<BingoGame?, String>((ref, gameId) {
  if (_signedOut(ref)) return Stream.value(null);
  return ref.watch(bingoRepositoryProvider).watchBingo(gameId);
});

// ---- 가로세로 퍼즐(P4-2) ----
final crosswordRepositoryProvider = Provider<CrosswordRepository>((ref) => CrosswordRepository());

/// 한 교실의 퍼즐 세트(최신순).
final classroomCrosswordsProvider =
    StreamProvider.family<List<CrosswordSet>, String>((ref, classroomId) {
  if (_signedOut(ref)) return Stream.value(const []);
  return ref.watch(crosswordRepositoryProvider).watchSetsByClassroom(classroomId);
});

/// 단일 퍼즐 세트.
final crosswordSetProvider =
    StreamProvider.family<CrosswordSet?, String>((ref, setId) {
  if (_signedOut(ref)) return Stream.value(null);
  return ref.watch(crosswordRepositoryProvider).watchSet(setId);
});

/// 학생: 내 풀이(이어풀기).
final myCrosswordSubmissionProvider =
    StreamProvider.family<CrosswordSubmission?, String>((ref, setId) {
  if (_signedOut(ref)) return Stream.value(null);
  return ref.watch(crosswordRepositoryProvider).watchMySubmission(setId);
});

/// 교사: 퍼즐 제출 현황.
final crosswordSubmissionsProvider =
    StreamProvider.family<List<CrosswordSubmission>, String>((ref, setId) {
  if (_signedOut(ref)) return Stream.value(const []);
  return ref.watch(crosswordRepositoryProvider).watchSubmissions(setId);
});

// ---- 퀴즈 대회(P4-3) ----
final quizRepositoryProvider = Provider<QuizRepository>((ref) => QuizRepository());

/// 한 교실의 퀴즈 대회(최신순).
final classroomQuizzesProvider =
    StreamProvider.family<List<QuizCompetition>, String>((ref, classroomId) {
  if (_signedOut(ref)) return Stream.value(const []);
  return ref.watch(quizRepositoryProvider).watchCompetitionsByClassroom(classroomId);
});

/// 단일 퀴즈 대회(실시간).
final quizCompetitionProvider =
    StreamProvider.family<QuizCompetition?, String>((ref, id) {
  if (_signedOut(ref)) return Stream.value(null);
  return ref.watch(quizRepositoryProvider).watchCompetition(id);
});

/// 실시간 랭킹.
final quizPlayersProvider =
    StreamProvider.family<List<QuizPlayer>, String>((ref, competitionId) {
  if (_signedOut(ref)) return Stream.value(const []);
  return ref.watch(quizRepositoryProvider).watchPlayers(competitionId);
});

/// 학생: 내 참가 기록(재도전 제한 판정).
final myQuizPlayerProvider =
    StreamProvider.family<QuizPlayer?, String>((ref, competitionId) {
  if (_signedOut(ref)) return Stream.value(null);
  return ref.watch(quizRepositoryProvider).watchMyPlayer(competitionId);
});
