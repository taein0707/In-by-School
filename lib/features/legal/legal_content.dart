// 법적 문서 — 번들 템플릿 초안(Markdown). 실서비스 전 법무 검토 후 교체하거나,
// LEGAL_BASE_URL 을 설정해 원격 Markdown 으로 대체할 수 있다(legal_page.dart 참고).
//
// 플레이스홀더([회사명] 등)는 실제 값으로 교체해야 한다.

const String kLegalEffectiveDate = '2026-01-01';

const String kPrivacyPolicyMd = '''
# 개인정보처리방침

시행일: $kLegalEffectiveDate

[회사명](이하 "회사")은 OCL Study(이하 "서비스") 이용자의 개인정보를 중요하게
생각하며, 「개인정보 보호법」 등 관련 법령을 준수합니다.

## 1. 수집하는 개인정보 항목
- 필수: 이메일, 비밀번호(암호화 저장), 표시 이름, 역할(학생/선생님)
- 자동 수집: 기기 식별 토큰(FCM), 서비스 이용 기록(학습/숙제/문제 풀이)

## 2. 개인정보의 수집 및 이용 목적
- 회원 식별 및 로그인
- 학생-선생님 연결 및 숙제/플래시카드/문제 배포
- 푸시 알림 발송
- 서비스 개선 및 통계

## 3. 보유 및 이용 기간
- 회원 탈퇴 시 지체 없이 파기합니다(법령상 보존 의무가 있는 경우 해당 기간 보관).

## 4. 제3자 제공
- 회사는 이용자의 동의 없이 개인정보를 외부에 제공하지 않습니다.
- 서비스 운영을 위해 Google Firebase(인증·데이터베이스·푸시)를 이용합니다.

## 5. 이용자의 권리
- 이용자는 언제든지 자신의 개인정보를 조회·수정하거나, 회원 탈퇴를 통해
  삭제를 요청할 수 있습니다(설정 > 회원 탈퇴).

## 6. 개인정보 파기
- 회원 탈퇴 시 users, teacherLinks, submissions, flashcardProgress,
  aiQuestionResults, notifications 등 관련 데이터를 즉시 삭제합니다.

## 7. 문의처
- 개인정보 보호책임자: [담당자명] / [이메일]

본 방침은 관련 법령 및 회사 정책에 따라 변경될 수 있으며, 변경 시 앱 내 공지합니다.
''';

const String kTermsOfServiceMd = '''
# 이용약관

시행일: $kLegalEffectiveDate

## 제1조 (목적)
본 약관은 [회사명](이하 "회사")이 제공하는 OCL Study(이하 "서비스")의 이용 조건과
절차, 회사와 이용자의 권리·의무를 규정함을 목적으로 합니다.

## 제2조 (정의)
- "이용자"란 본 약관에 동의하고 서비스를 이용하는 학생·선생님 회원을 말합니다.

## 제3조 (서비스의 제공)
- 학습 관리, 숙제·플래시카드·AI 문제 배포 및 풀이, 알림 기능을 제공합니다.
- 회사는 안정적 운영을 위해 서비스 내용을 변경할 수 있습니다.

## 제4조 (이용자의 의무)
- 이용자는 타인의 권리를 침해하거나 부적절한 콘텐츠를 게시해서는 안 됩니다.
- 계정 정보를 안전하게 관리할 책임은 이용자에게 있습니다.

## 제5조 (콘텐츠와 책임)
- 이용자가 작성한 메모·카드·문제 등의 콘텐츠에 대한 책임은 작성자에게 있습니다.
- 회사는 부적절한 콘텐츠를 사전 통지 없이 제한할 수 있습니다.

## 제6조 (계약 해지)
- 이용자는 언제든지 설정 > 회원 탈퇴를 통해 이용계약을 해지할 수 있습니다.

## 제7조 (면책)
- 천재지변, 이용자 귀책 등 회사의 합리적 통제를 벗어난 사유로 인한 손해에 대해
  회사는 책임을 지지 않습니다.

본 약관에 명시되지 않은 사항은 관련 법령 및 상관례에 따릅니다.
''';

/// 화면 키 → (제목, 번들 템플릿, 원격 파일명).
class LegalDoc {
  final String title;
  final String markdown;
  final String remoteFile; // LEGAL_BASE_URL/<remoteFile>
  const LegalDoc(this.title, this.markdown, this.remoteFile);
}

const Map<String, LegalDoc> kLegalDocs = {
  'privacy': LegalDoc('개인정보처리방침', kPrivacyPolicyMd, 'privacy.md'),
  'terms': LegalDoc('이용약관', kTermsOfServiceMd, 'terms.md'),
};
