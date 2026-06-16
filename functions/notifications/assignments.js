"use strict";

// 숙제 알림.
//  - assignments 생성     → 대상 학생 푸시("새 숙제가 도착했어요")
//  - submissions 완료     → 담당 선생님 푸시("○○ 학생이 숙제를 제출했습니다")

const { onDocumentCreated, onDocumentWritten } = require("firebase-functions/v2/firestore");
const { notify, acceptedStudents } = require("../lib/messaging");

const onAssignmentCreated = onDocumentCreated("assignments/{id}", async (event) => {
  const a = event.data && event.data.data();
  if (!a) return;
  // 수락된 연결 학생에게만 발송(임의 studentUids 스팸 차단).
  const targets = await acceptedStudents(a.teacherUid, a.studentUids);
  if (!targets.length) return;
  await notify(targets, {
    fromUid: a.teacherUid,
    kind: "newAssignment",
    title: "새 숙제가 도착했어요",
    body: a.title || "새 숙제",
    type: "assignment",
    refId: a.id || event.params.id,
  });
});

const onSubmissionDone = onDocumentWritten("submissions/{id}", async (event) => {
  const before = event.data.before.exists ? event.data.before.data() : null;
  const after = event.data.after.exists ? event.data.after.data() : null;
  if (!after) return;
  const wasDone = before && before.status === "done";
  if (after.status === "done" && !wasDone) {
    const name = (after.studentName || "").trim() || "학생";
    await notify([after.teacherUid], {
      fromUid: after.studentUid,
      kind: "submissionDone",
      title: "숙제 제출",
      body: `${name} 학생이 숙제를 제출했습니다`,
      type: "assignment",
      refId: after.assignmentId,
    });
  }
});

module.exports = { onAssignmentCreated, onSubmissionDone };
