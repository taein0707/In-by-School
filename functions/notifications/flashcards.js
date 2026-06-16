"use strict";

// 플래시카드 알림.
//  - flashcardDecks 생성       → 대상 학생 푸시("새 플래시카드가 도착했어요")
//  - flashcardProgress 완료     → 담당 선생님 푸시("○○ 학생이 단어 학습을 완료했습니다")

const { onDocumentCreated, onDocumentWritten } = require("firebase-functions/v2/firestore");
const { notify, acceptedStudents } = require("../lib/messaging");

const onDeckCreated = onDocumentCreated("flashcardDecks/{id}", async (event) => {
  const d = event.data && event.data.data();
  if (!d) return;
  const targets = await acceptedStudents(d.teacherUid, d.studentUids);
  if (!targets.length) return;
  await notify(targets, {
    fromUid: d.teacherUid,
    kind: "newFlashcards",
    title: "새 플래시카드가 도착했어요",
    body: d.title || "새 카드 덱",
    type: "deck",
    refId: d.id || event.params.id,
  });
});

const onFlashcardDone = onDocumentWritten("flashcardProgress/{id}", async (event) => {
  const before = event.data.before.exists ? event.data.before.data() : null;
  const after = event.data.after.exists ? event.data.after.data() : null;
  if (!after) return;
  const wasDone = before && before.status === "done";
  if (after.status === "done" && !wasDone) {
    const name = (after.studentName || "").trim() || "학생";
    await notify([after.teacherUid], {
      fromUid: after.studentUid,
      kind: "submissionDone",
      title: "학습 완료",
      body: `${name} 학생이 단어 학습을 완료했습니다`,
      type: "deck",
      refId: after.deckId,
    });
  }
});

module.exports = { onDeckCreated, onFlashcardDone };
