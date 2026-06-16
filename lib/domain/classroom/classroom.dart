// 교실(Classroom) — 향후 공지·수행평가·학습지·자리배치 등 교실 단위 기능의 공통 기반(P2-0).
// 기존 teacherLinks(교사↔학생 1:N 연결)는 그대로 유지하고, classrooms 를 '신규 추가'한다.
//
//   classrooms/{id}                          — 교실(교사 1명이 여러 개 생성)
//   classroomMembers/{classroomId_userUid}   — 교실 구성원(교사/학생)
//
// classroomMembers 는 보안규칙이 get() 없이 평가되도록 teacherUid 를 비정규화하고,
// 학생 목록을 추가 조회 없이 그릴 수 있게 classroomName 도 비정규화한다.

enum ClassroomRole {
  teacher,
  student;

  static ClassroomRole fromName(String? s) =>
      values.firstWhere((e) => e.name == s, orElse: () => ClassroomRole.student);
}

class Classroom {
  final String id;
  final String teacherUid;
  final String name;
  final String description;

  /// 학생 직접 참여용 가입 코드(P8 #4). 비어 있으면 코드 참여 비활성.
  final String joinCode;

  final DateTime? createdAt;

  const Classroom({
    required this.id,
    required this.teacherUid,
    this.name = '',
    this.description = '',
    this.joinCode = '',
    this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'teacherUid': teacherUid,
        'name': name,
        'description': description,
        'joinCode': joinCode,
        'createdAt': createdAt?.toIso8601String(),
      };

  factory Classroom.fromMap(Map<String, dynamic> m) => Classroom(
        id: m['id'] as String? ?? '',
        teacherUid: m['teacherUid'] as String? ?? '',
        name: m['name'] as String? ?? '',
        description: m['description'] as String? ?? '',
        joinCode: m['joinCode'] as String? ?? '',
        createdAt: (m['createdAt'] as String?) != null ? DateTime.tryParse(m['createdAt'] as String) : null,
      );
}

class ClassroomMember {
  final String id; // '{classroomId}_{userUid}'
  final String classroomId;
  final String classroomName; // 비정규화(학생 목록 표시용)
  final String userUid;
  final String teacherUid; // 비정규화(보안규칙용)
  final ClassroomRole role;
  final String displayName;
  final DateTime? joinedAt;

  const ClassroomMember({
    required this.id,
    required this.classroomId,
    this.classroomName = '',
    required this.userUid,
    required this.teacherUid,
    this.role = ClassroomRole.student,
    this.displayName = '',
    this.joinedAt,
  });

  static String idFor(String classroomId, String userUid) => '${classroomId}_$userUid';

  Map<String, dynamic> toMap() => {
        'id': id,
        'classroomId': classroomId,
        'classroomName': classroomName,
        'userUid': userUid,
        'teacherUid': teacherUid,
        'role': role.name,
        'displayName': displayName,
        'joinedAt': joinedAt?.toIso8601String(),
      };

  factory ClassroomMember.fromMap(Map<String, dynamic> m) => ClassroomMember(
        id: m['id'] as String? ?? '',
        classroomId: m['classroomId'] as String? ?? '',
        classroomName: m['classroomName'] as String? ?? '',
        userUid: m['userUid'] as String? ?? '',
        teacherUid: m['teacherUid'] as String? ?? '',
        role: ClassroomRole.fromName(m['role'] as String?),
        displayName: m['displayName'] as String? ?? '',
        joinedAt: (m['joinedAt'] as String?) != null ? DateTime.tryParse(m['joinedAt'] as String) : null,
      );
}
