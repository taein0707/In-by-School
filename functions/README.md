# OCL Study — Cloud Functions (FCM 푸시)

선생님↔학생 실제 백그라운드 푸시. **서버(Admin SDK)만 발송**하며, 클라이언트는
토큰 저장과 알림 클릭 이동만 담당한다(직접 발송 불가).

## 구조

```
functions/
  index.js                     # 진입점 — 모든 함수 재노출
  lib/messaging.js             # 공용: 토큰 조회·발송·무효 토큰 정리·알림함 기록
  notifications/
    assignments.js             # 숙제 생성→학생 / 제출 완료→선생님
    flashcards.js              # 덱 생성→학생 / 학습 완료→선생님
    aiQuestions.js             # 세트 생성→학생 / 풀이 완료→선생님
    dueSoon.js                 # 마감 24h/3h 전 스케줄 알림
```

## Firestore 트리거

| 함수 | 트리거 | 발송 대상 | 메시지 |
|---|---|---|---|
| `onAssignmentCreated` | `assignments/{id}` onCreate | 대상 학생 | 새 숙제가 도착했어요 |
| `onSubmissionDone` | `submissions/{id}` onWrite (→done) | 담당 선생님 | ○○ 학생이 숙제를 제출했습니다 |
| `onDeckCreated` | `flashcardDecks/{id}` onCreate | 대상 학생 | 새 플래시카드가 도착했어요 |
| `onFlashcardDone` | `flashcardProgress/{id}` onWrite (→done) | 담당 선생님 | ○○ 학생이 단어 학습을 완료했습니다 |
| `onQuestionSetCreated` | `aiQuestionSets/{id}` onCreate | 대상 학생 | 새 문제 세트가 도착했어요 |
| `onQuizResultDone` | `aiQuestionResults/{id}` onWrite (→completed) | 담당 선생님 | ○○ 학생이 AI 문제를 완료했습니다 |
| `assignmentDueSoon` | 스케줄 `every 60 minutes` | 대상 학생 | 내일 마감 / 마감 3시간 전 |

`onWrite` 트리거는 **상태 전이**(이전 ≠ done, 이후 = done)일 때만 발송해 중복을 막는다.
마감 알림은 숙제 문서에 `dueNotified24` / `dueNotified3` 마커를 남겨 1회만 보낸다.

## 알림 Payload 예시

```jsonc
// FCM 메시지(서버 → 기기)
{
  "notification": { "title": "새 숙제가 도착했어요", "body": "영단어 50개 암기" },
  "data": {
    "type": "assignment",          // assignment | deck | quizset
    "refId": "aB3xK9",             // 문서 ID (딥링크 대상)
    "kind": "newAssignment",        // 인앱 알림 종류
    "click_action": "FLUTTER_NOTIFICATION_CLICK"
  },
  "android": { "priority": "high", "notification": { "channelId": "ocl_push" } },
  "apns": { "payload": { "aps": { "sound": "default" } } }
}
```

동시에 인앱 알림함 문서도 생성된다:

```jsonc
// notifications/{auto}
{
  "toUid": "stu_001", "fromUid": "tcr_001",
  "kind": "newAssignment", "title": "새 숙제가 도착했어요",
  "body": "영단어 50개 암기", "refId": "aB3xK9",
  "read": false, "createdAt": "2026-06-12T09:30:00.000Z"
}
```

## 딥링크 구조

클라이언트는 `data.type` + `data.refId` 로 `/open?type=<type>&id=<refId>` 를 연다.
`DeepLinkPage` 가 문서를 불러와 역할별 상세로 이동한다.

| type | 선생님 | 학생 |
|---|---|---|
| `assignment` | `/t/assignments/detail` | `/assignments/detail` |
| `deck` | `/t/flashcards/detail` | `/flashcards`(탭) |
| `quizset` | `/t/ai/detail` | `/quizzes`(탭) |

3상태 처리: 포그라운드(로컬 알림 탭) · 백그라운드(`onMessageOpenedApp`) ·
종료(`getInitialMessage` → 라우터 준비 후 flush).

## 보안

- 발송은 Admin SDK 로만(서버 전용). 클라이언트에 서버 키 없음.
- `firestore.rules` 의 `notifications` 는 발신자 create / 수신자 read 만 허용하지만,
  Functions 는 Admin 권한으로 규칙을 우회해 안전하게 기록한다.
- **토큰 정리**: 발송 응답에서 `registration-token-not-registered` /
  `invalid-argument` 토큰을 감지해 `users/{uid}.fcmTokens` 에서 `arrayRemove`.

## AI 프록시 (`aiProxy`, H-2)

Gemini API 키를 클라이언트에 노출하지 않기 위한 HTTPS 중계. 키는 **Functions Secret**
(`GEMINI_API_KEY`)에 보관하고, 클라이언트는 Firebase ID 토큰을 실어 호출한다.

```bash
# 키를 시크릿으로 등록(최초 1회 / 갱신 시)
firebase functions:secrets:set GEMINI_API_KEY
```

배포 후 함수 URL(예: `https://<region>-<project>.cloudfunctions.net/aiProxy`)을
클라이언트 빌드에 주입한다(비밀 아님):

```bash
flutter build apk --dart-define=AI_PROXY_URL=https://<region>-<project>.cloudfunctions.net/aiProxy
```

URL 미설정 시 앱은 키 없이 동작하며 AI 기능은 오프라인 폴백으로 대체된다.

## 배포

전제: **Blaze 요금제**(아웃바운드 네트워크 필요), Node 20, `firebase-tools` 설치.

```bash
# 1) 프로젝트 지정 (.firebaserc 의 YOUR_FIREBASE_PROJECT_ID 를 실제 ID 로 교체하거나)
firebase use <project-id>

# 2) 의존성 설치
cd functions && npm install && cd ..

# 3) (최초) AI 키 시크릿 등록
firebase functions:secrets:set GEMINI_API_KEY

# 4) 배포 (functions + firestore 규칙)
firebase deploy --only functions,firestore:rules
```

## 보안 하드닝 (M1)

- **C-1**: 학생 대상 푸시는 발신 선생님과 **수락된 teacherLinks** 멤버에게만(서버에서 필터).
- **C-2**: FCM 토큰은 `users/{uid}/private/push`(본인 전용)로 격리, 공개 프로필에 PII(email) 미저장.
- **H-1**: `teacherLinks` 는 발신자 본인 pending 생성 / 당사자 uid 불변 수정만 허용.
- **H-3**: 숙제·덱·세트 삭제 시 제출/진행/결과까지 연쇄 삭제.
- **M-1**: 로그아웃·탈퇴 시 현재 기기 토큰 제거 + `deleteToken()`.

클라이언트는 Android `google-services.json`, iOS `GoogleService-Info.plist` + APNs 키가
설정되어야 실제 푸시를 수신한다(미설정 시 앱은 안전하게 동작, 푸시만 비활성).

## 비용 (Blaze)

가정: 학생 50명 · 선생님 5명 · 1일 숙제/카드/문제 배포 10건 · 학생 제출 200건/일.

| 항목 | 일 호출 | 월(30일) | 무료 구간 | 비용 |
|---|---|---|---|---|
| Functions 호출(트리거) | ~210 | ~6,300 | 200만/월 | **무료** |
| 스케줄(`every 60 min`) | 24 | 720 | 200만/월 | **무료** |
| FCM 메시지 | 수천 | 수만 | **무제한·무료** | **무료** |
| Firestore 추가 read/write(토큰·알림함) | ~1천 | ~3만 | 50K read·20K write/일 | 거의 무료 |
| Cloud Scheduler 작업 | 1개 | — | 3개/월 무료 | **무료** |

- **FCM 자체는 전액 무료**(메시지 수 제한 없음).
- Functions 무료 구간(2M 호출·400K GB-초/월)을 한참 밑돌아 **사실상 $0**.
- 유의미한 과금은 트래픽이 수십만 DAU 규모로 커진 뒤에야 발생.
- 예상 월 비용: **소규모(수백 명) 기준 ≈ $0**, 중규모(수천 명)도 월 몇 달러 수준.
