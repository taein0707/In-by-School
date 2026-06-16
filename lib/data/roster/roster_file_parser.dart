import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';

/// 업로드 파일(bytes) → 명단 원문 텍스트. 순수 Dart(플러그인 무의존) — 단위 테스트 가능.
///
///  - xlsx: [Excel] 로 디코드해 각 행의 셀을 탭으로 이어 붙인다.
///  - csv/txt/그 외: UTF-8(실패 시 latin1) 텍스트로 디코드.
///
/// 결과 텍스트는 [RosterBuilder.extractNames] 또는 Gemini 가 이름을 뽑는 입력이 된다.
class RosterFileParser {
  RosterFileParser._();

  static const Set<String> supportedExtensions = {'xlsx', 'csv', 'txt'};

  static String extensionOf(String filename) {
    final i = filename.lastIndexOf('.');
    return i < 0 ? '' : filename.substring(i + 1).toLowerCase();
  }

  static String parse({required String filename, required Uint8List bytes}) {
    return extensionOf(filename) == 'xlsx' ? _xlsx(bytes) : _text(bytes);
  }

  static String _text(Uint8List bytes) {
    try {
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      return latin1.decode(bytes, allowInvalid: true);
    }
  }

  static String _xlsx(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    final sb = StringBuffer();
    for (final table in excel.tables.values) {
      for (final row in table.rows) {
        final cells = row.map(_cellText).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
        if (cells.isNotEmpty) sb.writeln(cells.join('\t'));
      }
    }
    return sb.toString();
  }

  /// 셀 → 평문 문자열. TextCellValue 는 TextSpan 래퍼라 toString 이 아닌 .value.text 로 읽는다.
  static String _cellText(Data? cell) {
    final v = cell?.value;
    return switch (v) {
      null => '',
      TextCellValue() => v.value.text ?? '',
      IntCellValue() => v.value.toString(),
      DoubleCellValue() => _numText(v.value),
      BoolCellValue() => v.value ? 'true' : 'false',
      FormulaCellValue() => v.formula,
      _ => v.toString(),
    };
  }

  static String _numText(double d) =>
      d == d.roundToDouble() ? d.toInt().toString() : d.toString();
}
