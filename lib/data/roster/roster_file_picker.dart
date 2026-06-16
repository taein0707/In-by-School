import 'dart:typed_data';

import 'roster_file_picker_io.dart'
    if (dart.library.html) 'roster_file_picker_web.dart' as impl;

/// 선택한 명단 파일(이름 + 바이트).
class PickedRosterFile {
  final String name;
  final Uint8List bytes;
  const PickedRosterFile({required this.name, required this.bytes});
}

/// 파일 선택 창을 띄워 xlsx/csv/txt 명단을 읽는다(웹 전용).
/// 비웹/테스트에선 null 을 반환한다(호출부가 안내 메시지 처리).
Future<PickedRosterFile?> pickRosterFile() => impl.pickRosterFile();

/// 현재 플랫폼에서 파일 업로드 지원 여부(웹만 true).
bool get rosterPickerSupported => impl.rosterPickerSupported;
