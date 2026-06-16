/// 학교/학원 검색 결과 한 건(P9 #1).
enum InstitutionKind { school, academy }

class Institution {
  final String id;
  final String name;
  final String detail; // 지역/주소 등 보조 정보(목록 표시용)
  final InstitutionKind kind;

  const Institution({
    required this.id,
    required this.name,
    this.detail = '',
    required this.kind,
  });
}
