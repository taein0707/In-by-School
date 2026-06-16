import 'package:flutter/widgets.dart';

/// 비-웹(모바일/VM) 플레이스홀더 — P7 영상은 웹에서만 표시.
Widget studentScreenView({
  required String sessionId,
  required String teacherUid,
  required String studentUid,
}) =>
    const SizedBox.shrink();
