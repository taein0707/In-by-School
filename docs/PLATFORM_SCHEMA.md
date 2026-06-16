# OCL Study — 플랫폼 확장 데이터 모델 & 로드맵

학생 개인 앱 → 학교/학원/과외용 **학습 관리 플랫폼**으로 확장. 이 문서는
Firestore 스키마, 보안 모델, 단계별(phase) 로드맵을 한곳에 모은다.

기존 1인용 데이터는 그대로 둔다(`users/{uid}/state/spirit`, `users/{uid}/sessions/*`,
`users/{uid}/state/life`). 플랫폼 데이터는 **최상위 공유 컬렉션**으로 추가한다.

## Firestore 컬렉션

| 컬렉션 | 문서 ID | 소유 | 설명 |
|---|---|---|---|
| `users/{uid}` | uid | 본인 | 프로필 본문: `role`, `displayName`, `studentType`, `subject`, `orgType`, `orgName`, `fcmTokens[]`, `createdAt` |
| `inviteCodes/{CODE}` | 6자리 코드 | 선생님 | `{teacherUid}` 역참조. 학생이 코드 입력 시 선생님 조회 |
| `teacherLinks/{tUid_sUid}` | `{teacherUid}_{studentUid}` | 당사자 | `status`(pending/accepted/rejected), `initiatedBy`, 비정규화 이름/과목, `members[]` |
| `assignments/{id}` | auto | 선생님 | 숙제. `type`, `difficulty`, `priority`, `dueDate`, `studentUids[]` |
| `submissions/{aId_sUid}` | `{assignmentId}_{studentUid}` | 학생 | 학생별 진행/제출. `status`, `progress`, `memo`, `photoUrls[]`, `fileUrls[]` |
| `flashcardDecks/{id}` | auto | 선생님 | 덱 메타. `title`, `description`, `subject`, `cardCount`, `fromOcr`, `studentUids[]` |
| `flashcardCards/{id}` | auto | 선생님 | 카드. `deckId`, `front`, `back`, `example`, `hint`, `order` (+`teacherUid`/`studentUids[]` 비정규화) |
| `flashcardProgress/{dId_sUid}` | `{deckId}_{studentUid}` | 학생 | 학습 결과. `status`(fresh/learning/done), `studiedCards`, `totalCards`, `studySeconds`, `correctRate` |
| `aiQuestionSets/{id}` | auto | 선생님 | 세트 메타. `topic`, `difficulty`, `questionCount`, `sourceDeckId?`, `studentUids[]`, `fallbackUsed`, `aiModel`, `aiTotalTokens` |
| `aiQuestions/{id}` | auto | 선생님 | 문제. `setId`, `type`(multipleChoice/shortAnswer/fillBlank), `prompt`, `choices[]`, `answer`, `explanation`, `order` (+`teacherUid`/`studentUids[]` 비정규화) |
| `aiQuestionResults/{sId_sUid}` | `{setId}_{studentUid}` | 학생 | 자동 채점 결과. `total`, `correctCount`, `responses[]`(given/correct) |
| `notifications/{id}` | auto | 발신자 | 인앱 알림 + FCM 트리거 소스. `toUid`, `fromUid`, `kind`, `refId`, `read` |

설계 메모
- 다대다 배포는 `studentUids[]` 배열 + `array-contains` 쿼리로 학생 측 조회.
- 학생별 상태(submissions/results/attempts)는 배포 문서와 **분리**해 권한·동시성 단순화.
- `members[]`(teacherLinks)는 보안규칙/양방향 쿼리 편의용.
- 날짜는 기존 컨벤션대로 ISO8601 문자열(`toIso8601String`). 정렬 안정성 위해 동일 포맷 유지.

## 보안 모델 (`firestore.rules`)

- 토리 성장 데이터: 본인만.
- 프로필 본문: 본인 write, 인증 사용자 read(이름/과목 표시). **TODO**: 배포 전
  `teacherLinks` 연결 상대만 읽도록 좁히기.
- 배포 문서: 선생님(owner)만 create/update, 대상 학생은 read.
- submissions/results/attempts: 학생 본인 write, 담당 선생님 read.
- notifications: 수신자 read + read플래그 update, 발신자 create.

## 푸시 알림 — Cloud Functions + FCM (결정됨)

클라이언트(이미 구현):
- `FcmService.init()` — 권한 + 포그라운드 표시(로컬 알림 재사용).
- `FcmService.syncToken()` — `users/{uid}.fcmTokens` 에 기기 토큰 저장(가입/시작 시).
- `notifications/{id}` 문서 생성이 푸시의 단일 소스.

서버(다음 단계 — `functions/` 신설, Blaze 요금제 필요):
```js
// notifications/{id} 생성 → 수신자 토큰으로 FCM 발송
exports.onNotification = functions.firestore
  .document('notifications/{id}')
  .onCreate(async (snap) => {
    const n = snap.data();
    const user = await db.doc(`users/${n.toUid}`).get();
    const tokens = user.get('fcmTokens') || [];
    if (tokens.length) {
      await messaging.sendEachForMulticast({
        tokens, notification: { title: n.title, body: n.body },
        data: { kind: n.kind, refId: n.refId || '' },
      });
    }
  });
```
추가로 필요: 네이티브 설정(`google-services.json` / iOS APNs Key), 마감 임박
스케줄 함수(`onSchedule`)로 `dueSoon` 알림 생성.

## 단계별 로드맵

- **Phase 0 — 기반 (이번 작업, 완료)**
  - 도메인 모델 6종(account/assignment/flashcard/aiquestion/notification)
  - `AccountRepository`(프로필·초대코드·연결·FCM 토큰·알림)
  - Riverpod 프로바이더 + **역할 기반 라우팅**(학생 셸 `/home` ↔ 선생님 셸 `/t/*`)
  - 회원가입 플로우(유형 선택 → 학생[무소속/소속·코드] / 선생님[과목·소속])
  - FCM 클라이언트 + 보안규칙 + 본 문서
- **Phase 1 — 숙제 MVP (완료)**
  - 선생님: 숙제 생성(제목·설명·마감일·대상 학생 다중선택)·목록·상세(학생별 완료현황 실시간)
  - 학생: 숙제 탭(소속 학생)·목록·상세·완료 체크·메모 제출
  - 제출은 학생 지연 upsert(`submissions/{aId_sUid}`), Snapshot Listener 실시간 동기화
  - 제외(다음 단계): 사진/파일 첨부, 진행률 슬라이더, FCM 푸시, 인앱 알림 doc 생성
- **Phase 2 — 플래시 카드** ✅: 3컬렉션(`flashcardDecks`/`flashcardCards`/`flashcardProgress`)
  - 선생님: 덱 생성(직접 입력 + 기기 내 OCR `scanRawText` 검토·수정 후 카드화)·목록(완료현황)·상세(학생별 학습현황 실시간)·삭제
  - 학생: 카드 탭(소속)·새카드/학습중/완료 그룹·학습(일반/자가평가)·결과(시간·정답률·완료율) 저장
  - OCR은 ML Kit on-device만(서버/Gemini/과금 없음, 오프라인). 배포/진행은 Snapshot Listener 실시간
- **Phase 3 — AI 문제** ✅: 3컬렉션(`aiQuestionSets`/`aiQuestions`/`aiQuestionResults`)
  - 선생님: 독립 주제 또는 플래시카드 덱 연계 생성(`GeminiService.generateQuestions`)·검토/수정·배포·결과 확인
  - 학생: 풀이(객관식/단답/빈칸)·제출 시 자동 채점(`isCorrect` 정규화 비교)·문제별 정오/해설 결과
  - Gemini 실패 시 결정적 오프라인 폴백(`fallbackUsed`), 토큰 사용량(`aiTotalTokens`) 저장으로 비용 추적
- **Phase 4 — 통계**: 학생별 공부시간·완료율·정답률, 주간/월간 시각화
- **Phase 5 — Cloud Functions/FCM 서버 + 알림 마감 스케줄** ✅
  - `functions/` Node.js — Firestore 트리거(숙제/카드/문제 배포→학생, 제출/학습/풀이 완료→선생님) + 마감 24h/3h 스케줄
  - Admin SDK 서버 전용 발송, 무효 토큰 자동 정리, 인앱 알림함 동시 기록
  - 클라이언트 FCMService: 포그라운드/백그라운드/종료 3상태 + `/open?type=&id=` 딥링크 이동
  - 배포·비용: `functions/README.md`
- **Phase 6 — 학생 탭 개편**: 소속 학생 `오늘공부/성장/기록/숙제`,
  무소속 `…/마이 플랜`(목표·일정·체크리스트·반복·시험)
- **Phase 7 — 주간 리포트**(문자/카카오 알림톡) — 학부모 앱 대신

## 알려진 후속 정리(follow-up)

- 콜드 스타트 시 선생님이 잠깐 `/home` 을 거쳐 `/t/students` 로 리다이렉트됨
  → 스플래시/프로필 로딩 게이트로 부드럽게.
- 프로필 read 규칙을 연결 상대로 좁히기(위 TODO).
- 학생 ID(uid) 직접 입력 연결은 임시 — QR/코드 기반 UX로 개선.
