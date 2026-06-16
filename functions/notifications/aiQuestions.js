"use strict";

// AI 문제 알림.
//  - aiQuestionSets 생성        → 대상 학생 푸시("새 문제 세트가 도착했어요")
//  - aiQuestionResults 완료      → 담당 선생님 푸시("○○ 학생이 AI 문제를 완료했습니다")

const { onDocumentCreated, onDocumentWritten } = require("firebase-functions/v2/firestore");
const { notify, acceptedStudents } = require("../lib/messaging");

const onQuestionSetCreated = onDocumentCreated("aiQuestionSets/{id}", async (event) => {
  const s = event.data && event.data.data();
  if (!s) return;
  const targets = await acceptedStudents(s.teacherUid, s.studentUids);
  if (!targets.length) return;
  await notify(targets, {
    fromUid: s.teacherUid,
    kind: "newAiQuestions",
    title: "새 문제 세트가 도착했어요",
    body: s.title || "새 AI 문제",
    type: "quizset",
    refId: s.id || event.params.id,
  });
});

const onQuizResultDone = onDocumentWritten("aiQuestionResults/{id}", async (event) => {
  const before = event.data.before.exists ? event.data.before.data() : null;
  const after = event.data.after.exists ? event.data.after.data() : null;
  if (!after) return;
  const wasDone = before && before.completedAt;
  if (after.completedAt && !wasDone) {
    const name = (after.studentName || "").trim() || "학생";
    await notify([after.teacherUid], {
      fromUid: after.studentUid,
      kind: "submissionDone",
      title: "문제 풀이 완료",
      body: `${name} 학생이 AI 문제를 완료했습니다`,
      type: "quizset",
      refId: after.setId,
    });
  }
});

module.exports = { onQuestionSetCreated, onQuizResultDone };
