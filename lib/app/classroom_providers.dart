import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/firebase/classroom_repository.dart';
import '../data/firebase/bulk_student_repository.dart';
import '../domain/classroom/classroom.dart';
import 'account_providers.dart';

final classroomRepositoryProvider = Provider<ClassroomRepository>((ref) => ClassroomRepository());

/// P8-3 — 업로드 명단으로 학생 일괄 생성(보조 FirebaseApp).
final bulkStudentRepositoryProvider = Provider<BulkStudentRepository>((ref) => BulkStudentRepository());

/// 미인증(로그아웃/전환)이면 빈 스트림 — stale 리스너 permission-denied 방지.
bool _signedOut(Ref ref) =>
    Firebase.apps.isEmpty || ref.watch(authStateProvider).value == null;

/// 교사: 내가 만든 교실 목록(최신순).
final teacherClassroomsProvider = StreamProvider<List<Classroom>>((ref) {
  if (_signedOut(ref)) return Stream.value(const []);
  return ref.watch(classroomRepositoryProvider).watchClassroomsByTeacher();
});

/// 공통: 내가 속한 교실(구성원 기준).
final myClassroomsProvider = StreamProvider<List<ClassroomMember>>((ref) {
  if (_signedOut(ref)) return Stream.value(const []);
  return ref.watch(classroomRepositoryProvider).watchMyMemberships();
});

/// 교사: 한 교실의 학생 목록.
final classroomStudentsProvider =
    StreamProvider.family<List<ClassroomMember>, String>((ref, classroomId) {
  if (_signedOut(ref)) return Stream.value(const []);
  return ref.watch(classroomRepositoryProvider).watchStudentsInClassroom(classroomId);
});

/// 교사: 내 모든 교실의 학생(중복 제거) — 숙제/카드/AI 배포 대상.
/// 기존 teacherLinks(요청·승인) 로스터를 대체한다.
final teacherStudentsProvider = StreamProvider<List<ClassroomMember>>((ref) {
  if (_signedOut(ref)) return Stream.value(const []);
  return ref.watch(classroomRepositoryProvider).watchStudentsForTeacher();
});
