import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/institution/institution.dart';

/// 학교/학원 검색(P9 #1) — NEIS 교육정보 개방 포털(open.neis.go.kr).
///
/// 한 개의 API 키로 두 서비스를 모두 조회한다:
///   - 학교: `schoolInfo`     (SCHUL_NM 부분검색)
///   - 학원·교습소: `acaInsTiInfo` (ACA_NM 부분검색)
///
/// 키는 빌드 타임 주입으로 덮어쓸 수 있다(미지정 시 제공된 기본 키 사용):
///   flutter run --dart-define=NEIS_API_KEY=xxxx
///
/// 실패/무결과 시 항상 빈 리스트를 반환해 UI 가 막히지 않는다.
/// 참고: 일부 브라우저에서 CORS 가 막히면 웹 직접 호출이 실패할 수 있으며,
/// 이 경우 프록시(예: 기존 aiProxy 패턴)를 두면 된다.
class InstitutionSearchService {
  static const String _key =
      String.fromEnvironment('NEIS_API_KEY', defaultValue: '002d3aa91e8c44938a77495f5d186bc1');
  static const String _base = 'https://open.neis.go.kr/hub';
  static const Duration _timeout = Duration(seconds: 8);

  Future<List<Institution>> searchSchools(String query) => _fetch(
        path: 'schoolInfo',
        rootKey: 'schoolInfo',
        nameParam: 'SCHUL_NM',
        idField: 'SD_SCHUL_CODE',
        nameField: 'SCHUL_NM',
        detailField: 'ORG_RDNMA',
        kind: InstitutionKind.school,
        query: query,
      );

  Future<List<Institution>> searchAcademies(String query) => _fetch(
        path: 'acaInsTiInfo',
        rootKey: 'acaInsTiInfo',
        nameParam: 'ACA_NM',
        idField: 'ACA_ASNUM',
        nameField: 'ACA_NM',
        detailField: 'FA_RDNMA',
        kind: InstitutionKind.academy,
        query: query,
      );

  Future<List<Institution>> _fetch({
    required String path,
    required String rootKey,
    required String nameParam,
    required String idField,
    required String nameField,
    required String detailField,
    required InstitutionKind kind,
    required String query,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    try {
      final uri = Uri.parse('$_base/$path').replace(queryParameters: {
        'KEY': _key,
        'Type': 'json',
        'pIndex': '1',
        'pSize': '15',
        nameParam: q,
      });
      final res = await http.get(uri).timeout(_timeout);
      if (res.statusCode != 200) return const [];
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      return parseNeis(body,
          rootKey: rootKey, idField: idField, nameField: nameField, detailField: detailField, kind: kind);
    } catch (_) {
      return const [];
    }
  }

  /// NEIS 응답(JSON) → [Institution] 목록. 순수 함수 — 단위 테스트 가능.
  /// 응답 형태: `{ rootKey: [ {head:[...]}, {row:[ {...} ]} ] }`.
  /// 무결과면 `{ RESULT: {CODE:'INFO-200', ...} }` 라 rootKey 가 없다 → 빈 리스트.
  static List<Institution> parseNeis(
    dynamic body, {
    required String rootKey,
    required String idField,
    required String nameField,
    required String detailField,
    required InstitutionKind kind,
  }) {
    if (body is! Map) return const [];
    final root = body[rootKey];
    if (root is! List || root.length < 2) return const [];
    final rows = (root[1] as Map?)?['row'];
    if (rows is! List) return const [];
    final out = <Institution>[];
    final seen = <String>{};
    for (final r in rows) {
      if (r is! Map) continue;
      final name = (r[nameField] as String? ?? '').trim();
      if (name.isEmpty) continue;
      final id = (r[idField] as String? ?? '').trim();
      final detail = (r[detailField] as String? ?? '').trim();
      if (!seen.add('$id|$name')) continue; // 동일 학교/학원 중복 제거
      out.add(Institution(id: id, name: name, detail: detail, kind: kind));
    }
    return out;
  }
}
