import 'roster_file_picker.dart';

/// 비웹(VM/모바일/테스트) 스텁 — 파일 업로드 미지원.
Future<PickedRosterFile?> pickRosterFile() async => null;

bool get rosterPickerSupported => false;
