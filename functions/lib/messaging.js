"use strict";

// 공용 메시징 헬퍼 — Admin SDK 로만 발송(서버 전용). 클라이언트는 절대 직접
// 발송하지 않는다. 수신자 토큰은 users/{uid}.fcmTokens 에서 읽고, 무효 토큰은
// 발송 응답을 보고 정리(arrayRemove)한다. 인앱 알림함(notifications/{id})도 함께 기록.

const admin = require("firebase-admin");

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

/** 토큰 보관 문서 — users/{uid}/private/push.tokens[] (민감정보, 본인 전용). */
function pushDoc(uid) {
  return db.collection("users").doc(uid).collection("private").doc("push");
}

/** 알림 설정 문서 — users/{uid}/private/settings. */
function settingsDoc(uid) {
  return db.collection("users").doc(uid).collection("private").doc("settings");
}

// 딥링크 type → 설정 키.
const TYPE_TO_PREF = { assignment: "assignment", deck: "flashcard", quizset: "ai" };

/** 수신자가 해당 종류 푸시를 허용하는지(기본 허용). */
async function pushAllowed(uid, type) {
  const snap = await settingsDoc(uid).get().catch(() => null);
  if (!snap || !snap.exists) return true; // 미설정 = 전체 허용
  const p = snap.data() || {};
  if (p.all === false) return false;
  const key = TYPE_TO_PREF[type];
  return key ? p[key] !== false : true;
}

/** 토큰 읽기. 신규(private/push.tokens) 우선, 레거시(users.fcmTokens)도 흡수. */
async function tokensFor(uid) {
  if (!uid) return [];
  const set = new Set();
  const priv = await pushDoc(uid).get().catch(() => null);
  if (priv && priv.exists) {
    const t = priv.get("tokens");
    if (Array.isArray(t)) t.filter(Boolean).forEach((x) => set.add(x));
  }
  const userSnap = await db.collection("users").doc(uid).get().catch(() => null);
  if (userSnap && userSnap.exists) {
    const legacy = userSnap.get("fcmTokens");
    if (Array.isArray(legacy)) legacy.filter(Boolean).forEach((x) => set.add(x));
  }
  return [...set];
}

/** 무효 토큰 제거(토큰 정리 로직) — 양쪽 위치 모두 정리. */
async function pruneTokens(uid, tokens) {
  if (!uid || !tokens.length) return;
  const remove = admin.firestore.FieldValue.arrayRemove(...tokens);
  await Promise.all([
    pushDoc(uid).set({ tokens: remove }, { merge: true }).catch(() => {}),
    db.collection("users").doc(uid).update({ fcmTokens: remove }).catch(() => {}),
  ]);
}

/**
 * 보낸 사람(선생님)에게 '수락된 연결' 학생만 남긴다 — 임의 studentUids 로
 * 타인에게 스팸 푸시하는 것을 서버에서 차단(C-1).
 */
async function acceptedStudents(teacherUid, candidateUids) {
  const wanted = new Set((candidateUids || []).filter(Boolean));
  if (!teacherUid || !wanted.size) return [];
  const snap = await db
    .collection("teacherLinks")
    .where("teacherUid", "==", teacherUid)
    .where("status", "==", "accepted")
    .get()
    .catch(() => null);
  if (!snap) return [];
  const linked = new Set();
  snap.docs.forEach((d) => {
    const sid = d.get("studentUid");
    if (sid && wanted.has(sid)) linked.add(sid);
  });
  return [...linked];
}

const INVALID_CODES = new Set([
  "messaging/registration-token-not-registered",
  "messaging/invalid-registration-token",
  "messaging/invalid-argument",
]);

/**
 * 한 사용자에게 푸시. 그 사용자의 모든 기기 토큰으로 멀티캐스트 후
 * 실패(무효) 토큰을 정리한다. 반환: 성공 건수.
 */
async function sendToUser(uid, { title, body, data }) {
  const tokens = await tokensFor(uid);
  if (!tokens.length) return 0;

  const stringData = {};
  Object.entries(data || {}).forEach(([k, v]) => {
    stringData[k] = v == null ? "" : String(v);
  });
  // 클릭 라우팅 힌트.
  stringData.click_action = "FLUTTER_NOTIFICATION_CLICK";

  const res = await admin.messaging().sendEachForMulticast({
    tokens,
    notification: { title, body },
    data: stringData,
    android: {
      priority: "high",
      notification: { channelId: "ocl_push", sound: "default" },
    },
    apns: {
      payload: { aps: { sound: "default", contentAvailable: true } },
    },
  });

  const bad = [];
  res.responses.forEach((r, i) => {
    if (!r.success && r.error && INVALID_CODES.has(r.error.code)) {
      bad.push(tokens[i]);
    }
  });
  if (bad.length) await pruneTokens(uid, bad);
  return res.successCount;
}

/**
 * 여러 수신자에게: 인앱 알림함 문서 생성 + 푸시 발송.
 * @param {string[]} uids 수신자 uid 목록
 * @param {object} p { fromUid, kind, title, body, type, refId }
 *   - kind: 인앱 알림 종류(NotifKind)
 *   - type/refId: 딥링크용(클라이언트가 /open?type=&id= 로 이동)
 */
async function notify(uids, p) {
  const list = [...new Set((uids || []).filter(Boolean))];
  if (!list.length) return;
  const now = new Date().toISOString();
  await Promise.all(
    list.map(async (toUid) => {
      // 인앱 알림함은 항상 기록(앱 내에서 확인 가능).
      const ref = db.collection("notifications").doc();
      await ref
        .set({
          id: ref.id,
          toUid,
          fromUid: p.fromUid || "",
          kind: p.kind,
          title: p.title,
          body: p.body,
          refId: p.refId || null,
          read: false,
          createdAt: now,
        })
        .catch(() => {});
      // 푸시는 수신자 설정을 확인해 종류별로 건다.
      if (!(await pushAllowed(toUid, p.type))) return;
      await sendToUser(toUid, {
        title: p.title,
        body: p.body,
        data: { type: p.type, refId: p.refId || "", kind: p.kind },
      }).catch(() => {});
    })
  );
}

module.exports = { admin, db, tokensFor, sendToUser, notify, acceptedStudents };
