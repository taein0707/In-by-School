import 'package:flutter/widgets.dart';

// 웹에서만 실제 영상 렌더링(RTCVideoView). 비-웹은 플레이스홀더.
import 'student_screen_view_io.dart' if (dart.library.html) 'student_screen_view_web.dart' as impl;

/// P7 — 교사: 한 학생의 실시간 화면(WebRTC answerer + RTCVideoView).
/// [sessionId] 는 수락된 screenShareRequests 문서 id.
Widget studentScreenView({
  required String sessionId,
  required String teacherUid,
  required String studentUid,
}) =>
    impl.studentScreenView(sessionId: sessionId, teacherUid: teacherUid, studentUid: studentUid);
