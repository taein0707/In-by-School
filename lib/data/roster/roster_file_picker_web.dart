// 웹 전용 파일 업로드 — dart:html 은 조건부 임포트(dart.library.html)로 웹에서만 컴파일.
// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

import 'roster_file_picker.dart';

bool get rosterPickerSupported => true;

/// <input type=file> 을 띄워 명단 파일 1개를 읽어 바이트로 돌려준다.
/// 사용자가 취소하면(파일 미선택) null.
Future<PickedRosterFile?> pickRosterFile() async {
  final input = html.FileUploadInputElement()..accept = '.xlsx,.csv,.txt';
  input.click();
  await input.onChange.first;
  final files = input.files;
  if (files == null || files.isEmpty) return null;
  final file = files.first;

  final reader = html.FileReader()..readAsArrayBuffer(file);
  await reader.onLoadEnd.first;
  final result = reader.result;

  final Uint8List bytes;
  if (result is ByteBuffer) {
    bytes = result.asUint8List();
  } else if (result is Uint8List) {
    bytes = result;
  } else if (result is List<int>) {
    bytes = Uint8List.fromList(result);
  } else {
    return null;
  }
  return PickedRosterFile(name: file.name, bytes: bytes);
}
