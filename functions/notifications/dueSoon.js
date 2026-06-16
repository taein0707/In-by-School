"use strict";

// 숙제 마감 임박 알림(스케줄) — 24시간 전 / 3시간 전 각 1회.
// 매시간 실행해 24~3시간 내 마감 숙제를 찾아 대상 학생에게 푸시.
// 중복 방지 마커(dueNotified24/dueNotified3)를 숙제 문서에 기록한다.
//
// NOTE: dueDate 는 클라이언트가 DateTime.toIso8601String() 로 저장(타임존 표기 없음,
//   'YYYY-MM-DDTHH:mm:ss.SSS', 길이 23). 동일 포맷 문자열은 사전식==시간순이라
//   범위 쿼리가 동작한다. 함수 런타임(UTC)과 클라이언트 로컬시간 간 오프셋은
//   현재 스키마의 한계로, 윈도우를 25h 로 약간 넓혀 흡수한다.

const { onSchedule } = require("firebase-functions/v2/scheduler");
const { db, notify, acceptedStudents } = require("../lib/messaging");

function isoNoTz(ms) {
  return new Date(ms).toISOString().slice(0, 23); // drop trailing 'Z'
}

const assignmentDueSoon = onSchedule("every 60 minutes", async () => {
  const now = Date.now();
  const lowerIso = isoNoTz(now - 60 * 60 * 1000); // 살짝 과거까지 포함
  const upperIso = isoNoTz(now + 25 * 60 * 60 * 1000);

  const snap = await db
    .collection("assignments")
    .where("dueDate", ">=", lowerIso)
    .where("dueDate", "<=", upperIso)
    .get();

  for (const doc of snap.docs) {
    const a = doc.data();
    if (!a.dueDate) continue;
    const due = Date.parse(a.dueDate);
    if (isNaN(due)) continue;
    const hrs = (due - now) / 3600000;

    const targets = await acceptedStudents(a.teacherUid, a.studentUids);
    if (!targets.length) continue;

    if (hrs > 0 && hrs <= 3 && !a.dueNotified3) {
      await notify(targets, {
        fromUid: a.teacherUid,
        kind: "dueSoon",
        title: "마감 3시간 전",
        body: `${a.title || "숙제"} 마감이 곧이에요`,
        type: "assignment",
        refId: a.id || doc.id,
      });
      await doc.ref.update({ dueNotified3: true, dueNotified24: true }).catch(() => {});
    } else if (hrs > 3 && hrs <= 24 && !a.dueNotified24) {
      await notify(targets, {
        fromUid: a.teacherUid,
        kind: "dueSoon",
        title: "내일 마감",
        body: `${a.title || "숙제"} 마감이 하루 남았어요`,
        type: "assignment",
        refId: a.id || doc.id,
      });
      await doc.ref.update({ dueNotified24: true }).catch(() => {});
    }
  }
});

module.exports = { assignmentDueSoon };
