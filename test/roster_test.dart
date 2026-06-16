import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ocl_study/domain/account/roster.dart';
import 'package:ocl_study/domain/account/user_profile.dart';
import 'package:ocl_study/data/roster/roster_file_parser.dart';

void main() {
  group('romanizeHandle', () {
    test('spec examples — 성 표기 + 이름 이니셜', () {
      expect(RosterBuilder.romanizeHandle('김철수'), 'kimcs');
      expect(RosterBuilder.romanizeHandle('이영희'), 'leeyh');
      expect(RosterBuilder.romanizeHandle('박민수'), 'parkms');
    });

    test('비한글 이름은 영문/숫자만 소문자로', () {
      expect(RosterBuilder.romanizeHandle('John Doe'), 'johndoe');
      expect(RosterBuilder.romanizeHandle('!!!'), ''); // 추출 불가 → 빈 문자열
    });
  });

  group('build (이메일 자동 부여)', () {
    test('spec 예시 이메일', () {
      final r = RosterBuilder.build(['김철수', '이영희', '박민수']);
      expect(r.map((e) => e.email), [
        'kimcs01@school.local',
        'leeyh02@school.local',
        'parkms03@school.local',
      ]);
    });

    test('동명이인도 순번으로 이메일이 유일하다', () {
      final r = RosterBuilder.build(['김철수', '김철수']);
      expect(r[0].email, 'kimcs01@school.local');
      expect(r[1].email, 'kimcs02@school.local');
      expect(r[0].email == r[1].email, isFalse);
    });

    test('도메인 지정 + 빈 이름 제거', () {
      final r = RosterBuilder.build(['김철수', '  ', '이영희'], domain: 'ocl.kr');
      expect(r.length, 2);
      expect(r[0].email, 'kimcs01@ocl.kr');
      expect(r[1].email, 'leeyh02@ocl.kr');
    });

    test('Gemini 핸들이 있으면 우선 사용', () {
      final r = RosterBuilder.build(['김철수'], handles: ['kimchulsoo']);
      expect(r.first.email, 'kimchulsoo01@school.local');
    });
  });

  group('extractNames (휴리스틱 폴백)', () {
    test('예시1 — 이름 헤더 + 한 열', () {
      expect(RosterBuilder.extractNames('이름\n김철수\n이영희\n박민수'),
          ['김철수', '이영희', '박민수']);
    });

    test('예시2 — 번호+이름 CSV', () {
      expect(RosterBuilder.extractNames('번호,이름\n1,김철수\n2,이영희\n3,박민수'),
          ['김철수', '이영희', '박민수']);
    });

    test('예시2 — 번호+이름 탭 구분(엑셀 추출형)', () {
      expect(RosterBuilder.extractNames('번호\t이름\n1\t김철수\n2\t이영희\n3\t박민수'),
          ['김철수', '이영희', '박민수']);
    });

    test('예시3 — 이름만 한 줄씩', () {
      expect(RosterBuilder.extractNames('김철수\n이영희\n박민수'),
          ['김철수', '이영희', '박민수']);
    });

    test('한 셀에 "번호 이름"이 붙어도 순번을 떼어낸다', () {
      expect(RosterBuilder.extractNames('1 김철수\n2 이영희'), ['김철수', '이영희']);
    });
  });

  group('RosterFileParser', () {
    test('txt/csv는 UTF-8 텍스트로 디코드', () {
      final bytes = Uint8List.fromList(utf8.encode('김철수\n이영희'));
      final raw = RosterFileParser.parse(filename: 'roster.txt', bytes: bytes);
      expect(RosterBuilder.extractNames(raw), ['김철수', '이영희']);
    });

    test('xlsx 라운드트립 — 셀에서 이름 추출', () {
      final ex = Excel.createExcel();
      final sheet = ex[ex.getDefaultSheet()!];
      sheet.appendRow([TextCellValue('번호'), TextCellValue('이름')]);
      sheet.appendRow([IntCellValue(1), TextCellValue('김철수')]);
      sheet.appendRow([IntCellValue(2), TextCellValue('이영희')]);
      sheet.appendRow([IntCellValue(3), TextCellValue('박민수')]);
      final bytes = Uint8List.fromList(ex.encode()!);

      final raw = RosterFileParser.parse(filename: 'roster.xlsx', bytes: bytes);
      expect(RosterBuilder.extractNames(raw), ['김철수', '이영희', '박민수']);
    });
  });

  group('UserProfile.mustChangePassword', () {
    test('toPublicMap/fromMap 왕복', () {
      const p = UserProfile(uid: 'u1', role: UserRole.student, displayName: '김철수', mustChangePassword: true);
      final back = UserProfile.fromMap(p.toPublicMap());
      expect(back.mustChangePassword, isTrue);
    });

    test('기본값은 false', () {
      final back = UserProfile.fromMap(const UserProfile(uid: 'u1', role: UserRole.student).toMap());
      expect(back.mustChangePassword, isFalse);
    });
  });
}
