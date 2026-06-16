// 플랫폼 확장의 뿌리 — 한 계정이 학생인지 선생님인지, 어떤 소속인지.
// 기존 토리 성장 데이터(users/{uid}/state·sessions)와 별개로, 사용자 문서
// users/{uid} 본문에 저장된다.

enum UserRole {
  student,
  teacher;

  String get label => this == UserRole.student ? '학생' : '선생님';

  static UserRole fromName(String? s) =>
      values.firstWhere((e) => e.name == s, orElse: () => UserRole.student);
}

/// 학생 유형 — 무소속(혼자) vs 소속(선생님과 연결).
enum StudentType {
  independent, // 무소속
  affiliated; // 소속

  String get label => this == StudentType.independent ? '무소속' : '소속';

  static StudentType fromName(String? s) =>
      values.firstWhere((e) => e.name == s, orElse: () => StudentType.independent);
}

/// 선생님(또는 소속 학생)의 소속 유형.
enum OrgType {
  school, // 학교
  academy, // 학원
  tutoring; // 과외

  String get label => switch (this) {
        OrgType.school => '학교',
        OrgType.academy => '학원',
        OrgType.tutoring => '과외',
      };

  static OrgType? fromName(String? s) {
    if (s == null) return null;
    for (final e in values) {
      if (e.name == s) return e;
    }
    return null;
  }
}

/// 한 계정의 신원·역할. 익명 → 이메일 연결 후 이 문서로 역할이 확정된다.
class UserProfile {
  final String uid;
  final UserRole role;
  final String displayName;
  final String? email;

  // 학생 전용
  final StudentType studentType;

  // 선생님 전용
  final String? subject; // 담당 과목
  final OrgType? orgType; // 소속 유형
  final String? orgName; // 소속 이름(학교/학원 명). 선택.

  // 학교/학원 검색 결과(P9 #1) — 선택. orgName 과 함께 보관한다.
  final String? schoolId;
  final String? schoolName;
  final String? academyId;
  final String? academyName;

  // 푸시: 기기별 FCM 토큰(다기기 지원).
  final List<String> fcmTokens;

  /// 일괄 생성된 학생의 임시 비밀번호 강제 변경 플래그(P8-3).
  /// true 이면 라우터가 비밀번호 변경 화면 외 접근을 막는다.
  final bool mustChangePassword;

  final DateTime? createdAt;

  const UserProfile({
    required this.uid,
    required this.role,
    this.displayName = '',
    this.email,
    this.studentType = StudentType.independent,
    this.subject,
    this.orgType,
    this.orgName,
    this.schoolId,
    this.schoolName,
    this.academyId,
    this.academyName,
    this.fcmTokens = const [],
    this.mustChangePassword = false,
    this.createdAt,
  });

  bool get isTeacher => role == UserRole.teacher;
  bool get isStudent => role == UserRole.student;
  bool get isAffiliatedStudent => isStudent && studentType == StudentType.affiliated;

  UserProfile copyWith({
    String? uid,
    UserRole? role,
    String? displayName,
    String? email,
    StudentType? studentType,
    String? subject,
    OrgType? orgType,
    String? orgName,
    String? schoolId,
    String? schoolName,
    String? academyId,
    String? academyName,
    List<String>? fcmTokens,
    bool? mustChangePassword,
    DateTime? createdAt,
  }) =>
      UserProfile(
        uid: uid ?? this.uid,
        role: role ?? this.role,
        displayName: displayName ?? this.displayName,
        email: email ?? this.email,
        studentType: studentType ?? this.studentType,
        subject: subject ?? this.subject,
        orgType: orgType ?? this.orgType,
        orgName: orgName ?? this.orgName,
        schoolId: schoolId ?? this.schoolId,
        schoolName: schoolName ?? this.schoolName,
        academyId: academyId ?? this.academyId,
        academyName: academyName ?? this.academyName,
        fcmTokens: fcmTokens ?? this.fcmTokens,
        mustChangePassword: mustChangePassword ?? this.mustChangePassword,
        createdAt: createdAt ?? this.createdAt,
      );

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'role': role.name,
        'displayName': displayName,
        'email': email,
        'studentType': studentType.name,
        'subject': subject,
        'orgType': orgType?.name,
        'orgName': orgName,
        'schoolId': schoolId,
        'schoolName': schoolName,
        'academyId': academyId,
        'academyName': academyName,
        'fcmTokens': fcmTokens,
        'mustChangePassword': mustChangePassword,
        'createdAt': createdAt?.toIso8601String(),
      };

  /// 공개 프로필(연결 상대가 읽음) — PII(email)·민감정보(fcmTokens) 제외.
  /// 이메일은 FirebaseAuth 가, 토큰은 users/{uid}/private/push 가 보관한다.
  Map<String, dynamic> toPublicMap() => {
        'uid': uid,
        'role': role.name,
        'displayName': displayName,
        'studentType': studentType.name,
        'subject': subject,
        'orgType': orgType?.name,
        'orgName': orgName,
        'schoolId': schoolId,
        'schoolName': schoolName,
        'academyId': academyId,
        'academyName': academyName,
        'mustChangePassword': mustChangePassword,
        'createdAt': createdAt?.toIso8601String(),
      };

  factory UserProfile.fromMap(Map<String, dynamic> m) => UserProfile(
        uid: m['uid'] as String? ?? '',
        role: UserRole.fromName(m['role'] as String?),
        displayName: m['displayName'] as String? ?? '',
        email: m['email'] as String?,
        studentType: StudentType.fromName(m['studentType'] as String?),
        subject: m['subject'] as String?,
        orgType: OrgType.fromName(m['orgType'] as String?),
        orgName: m['orgName'] as String?,
        schoolId: m['schoolId'] as String?,
        schoolName: m['schoolName'] as String?,
        academyId: m['academyId'] as String?,
        academyName: m['academyName'] as String?,
        fcmTokens: (m['fcmTokens'] as List?)?.whereType<String>().toList() ?? const [],
        mustChangePassword: m['mustChangePassword'] as bool? ?? false,
        createdAt: (m['createdAt'] as String?) != null
            ? DateTime.tryParse(m['createdAt'] as String)
            : null,
      );
}
