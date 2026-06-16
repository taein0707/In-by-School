import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 교사 워크스페이스 컨텍스트(P9-2) — 사이드바에서 고른 '현재 교실'.
/// 모든 교사 GNB 화면(홈/숙제/학생/수업)이 이 값을 읽어 해당 교실 기준으로 스코프된다.
/// classroomId == null 이면 '전체 교실'.
class TeacherWorkspace {
  final String? classroomId;
  final String? classroomName;
  const TeacherWorkspace({this.classroomId, this.classroomName});

  bool get isAll => classroomId == null || classroomId!.isEmpty;
  String get title => isAll ? '전체 교실' : (classroomName?.isNotEmpty == true ? classroomName! : '교실');
}

class TeacherWorkspaceNotifier extends Notifier<TeacherWorkspace> {
  @override
  TeacherWorkspace build() => const TeacherWorkspace();

  void select(String classroomId, String classroomName) =>
      state = TeacherWorkspace(classroomId: classroomId, classroomName: classroomName);

  void selectAll() => state = const TeacherWorkspace();
}

/// 현재 교실(전체 또는 특정 교실). 사이드바가 갱신하고 GNB 화면이 watch 한다.
final teacherWorkspaceProvider =
    NotifierProvider<TeacherWorkspaceNotifier, TeacherWorkspace>(TeacherWorkspaceNotifier.new);
