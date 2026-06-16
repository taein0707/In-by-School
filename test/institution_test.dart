import 'package:flutter_test/flutter_test.dart';

import 'package:ocl_study/data/firebase/account_repository.dart';
import 'package:ocl_study/data/institution/institution_search_service.dart';
import 'package:ocl_study/domain/institution/institution.dart';

void main() {
  group('InstitutionSearchService.parseNeis', () {
    test('학교 응답 → 학교 목록', () {
      final body = {
        'schoolInfo': [
          {
            'head': [
              {'list_total_count': 2},
              {'RESULT': {'CODE': 'INFO-000', 'MESSAGE': '정상 처리되었습니다.'}},
            ]
          },
          {
            'row': [
              {'SD_SCHUL_CODE': '7530079', 'SCHUL_NM': '안양고등학교', 'ORG_RDNMA': '경기도 안양시'},
              {'SD_SCHUL_CODE': '7530080', 'SCHUL_NM': '안양외국어고등학교', 'ORG_RDNMA': '경기도 안양시'},
            ]
          },
        ]
      };
      final out = InstitutionSearchService.parseNeis(body,
          rootKey: 'schoolInfo',
          idField: 'SD_SCHUL_CODE',
          nameField: 'SCHUL_NM',
          detailField: 'ORG_RDNMA',
          kind: InstitutionKind.school);
      expect(out.map((e) => e.name), ['안양고등학교', '안양외국어고등학교']);
      expect(out.first.id, '7530079');
      expect(out.first.kind, InstitutionKind.school);
      expect(out.first.detail, '경기도 안양시');
    });

    test('학원 응답 → 학원 목록', () {
      final body = {
        'acaInsTiInfo': [
          {'head': []},
          {
            'row': [
              {'ACA_ASNUM': 'A1', 'ACA_NM': '메가스터디 안양점', 'FA_RDNMA': '안양시 만안구'},
            ]
          },
        ]
      };
      final out = InstitutionSearchService.parseNeis(body,
          rootKey: 'acaInsTiInfo',
          idField: 'ACA_ASNUM',
          nameField: 'ACA_NM',
          detailField: 'FA_RDNMA',
          kind: InstitutionKind.academy);
      expect(out.single.name, '메가스터디 안양점');
      expect(out.single.kind, InstitutionKind.academy);
    });

    test('무결과(RESULT 에러)면 빈 리스트', () {
      final body = {
        'RESULT': {'CODE': 'INFO-200', 'MESSAGE': '해당하는 데이터가 없습니다.'}
      };
      final out = InstitutionSearchService.parseNeis(body,
          rootKey: 'schoolInfo',
          idField: 'SD_SCHUL_CODE',
          nameField: 'SCHUL_NM',
          detailField: 'ORG_RDNMA',
          kind: InstitutionKind.school);
      expect(out, isEmpty);
    });

    test('동일 학교 중복 제거', () {
      final body = {
        'schoolInfo': [
          {'head': []},
          {
            'row': [
              {'SD_SCHUL_CODE': 'X', 'SCHUL_NM': '안양고등학교'},
              {'SD_SCHUL_CODE': 'X', 'SCHUL_NM': '안양고등학교'},
            ]
          },
        ]
      };
      final out = InstitutionSearchService.parseNeis(body,
          rootKey: 'schoolInfo',
          idField: 'SD_SCHUL_CODE',
          nameField: 'SCHUL_NM',
          detailField: 'ORG_RDNMA',
          kind: InstitutionKind.school);
      expect(out.length, 1);
    });
  });

  group('AccountRepository.normalizeEmail (P9 #8)', () {
    test('공백 제거 + 소문자', () {
      expect(AccountRepository.normalizeEmail('  Foo@Bar.COM '), 'foo@bar.com');
      expect(AccountRepository.normalizeEmail('STUDENT01@School.Local'), 'student01@school.local');
    });
  });
}
