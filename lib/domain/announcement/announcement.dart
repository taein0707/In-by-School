// 공지사항(Announcement, P2-1) — Classroom 기반. 교사가 교실별 공지/숙제/수행평가/일정을
// 작성하고 학생이 확인. announcements 를 '신규 추가'(기존 구조 변경 없음).
//
//   announcements/{id}  { classroomId, teacherUid, title, content, type, createdAt, updatedAt }

enum AnnouncementType {
  notice, // 공지
  assignment, // 숙제
  exam, // 수행평가
  event; // 일정/행사

  static AnnouncementType fromName(String? s) =>
      values.firstWhere((e) => e.name == s, orElse: () => AnnouncementType.notice);

  String get label => switch (this) {
        AnnouncementType.notice => '공지',
        AnnouncementType.assignment => '숙제',
        AnnouncementType.exam => '수행평가',
        AnnouncementType.event => '일정',
      };
}

class Announcement {
  final String id;
  final String classroomId;
  final String teacherUid;
  final String title;
  final String content;
  final AnnouncementType type;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Announcement({
    required this.id,
    required this.classroomId,
    required this.teacherUid,
    this.title = '',
    this.content = '',
    this.type = AnnouncementType.notice,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'classroomId': classroomId,
        'teacherUid': teacherUid,
        'title': title,
        'content': content,
        'type': type.name,
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory Announcement.fromMap(Map<String, dynamic> m) => Announcement(
        id: m['id'] as String? ?? '',
        classroomId: m['classroomId'] as String? ?? '',
        teacherUid: m['teacherUid'] as String? ?? '',
        title: m['title'] as String? ?? '',
        content: m['content'] as String? ?? '',
        type: AnnouncementType.fromName(m['type'] as String?),
        createdAt: (m['createdAt'] as String?) != null ? DateTime.tryParse(m['createdAt'] as String) : null,
        updatedAt: (m['updatedAt'] as String?) != null ? DateTime.tryParse(m['updatedAt'] as String) : null,
      );
}
