const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { setGlobalOptions } = require("firebase-functions/v2");
const admin = require("firebase-admin");

admin.initializeApp();

// 과금 가드: 인스턴스 상한 + 최소 메모리. 함수는 Firestore에 쓰지 않음(무한 트리거 불가)
setGlobalOptions({
  region: "asia-northeast3",
  maxInstances: 2,
  memory: "256MiB",
});

// 알림 판단에 쓰는 이벤트 필드 — 이 중 하나라도 바뀌어야 "수정"으로 침
const MEANINGFUL_FIELDS = [
  "title",
  "description",
  "startDateTime",
  "endDateTime",
  "isAllDay",
  "color",
  "icon",
  "repeat",
  "repeatUntil",
  "excludedDates",
];

function hasMeaningfulChange(before, after) {
  return MEANINGFUL_FIELDS.some((field) => {
    const a = normalize(before[field]);
    const b = normalize(after[field]);
    return JSON.stringify(a) !== JSON.stringify(b);
  });
}

function normalize(value) {
  if (value === undefined) return null;
  // Firestore Timestamp → millis
  if (value && typeof value.toMillis === "function") return value.toMillis();
  if (Array.isArray(value)) {
    return value.map((v) =>
      v && typeof v.toMillis === "function" ? v.toMillis() : v
    );
  }
  return value;
}

function formatStart(timestamp, isAllDay) {
  const date = timestamp.toDate();
  const parts = new Intl.DateTimeFormat("ko-KR", {
    timeZone: "Asia/Seoul",
    month: "numeric",
    day: "numeric",
    weekday: "short",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  }).formatToParts(date);
  const get = (type) => parts.find((p) => p.type === type)?.value ?? "";
  const base = `${get("month")}월 ${get("day")}일 (${get("weekday")})`;
  return isAllDay ? `${base} 종일` : `${base} ${get("hour")}:${get("minute")}`;
}

async function sendToPartner(event, eventId, actorUid, notificationTitle) {
  const db = admin.firestore();

  const coupleId = event.coupleId ?? "";
  if (!coupleId || !actorUid) return;

  const coupleSnap = await db.collection("couples").doc(coupleId).get();
  if (!coupleSnap.exists) return;
  const couple = coupleSnap.data();
  if (couple.isLinked !== true) return;

  const partnerUid =
    couple.ownerUid === actorUid ? couple.partnerUid : couple.ownerUid;
  if (!partnerUid || partnerUid === actorUid) return;

  const [partnerSnap, actorSnap] = await Promise.all([
    db.collection("users").doc(partnerUid).get(),
    db.collection("users").doc(actorUid).get(),
  ]);
  const fcmToken = partnerSnap.data()?.fcmToken ?? "";
  if (!fcmToken) return;

  const actorName = (actorSnap.data()?.displayName ?? "").trim() || "상대방";
  const title = (event.title ?? "").trim() || "(제목 없음)";
  const when = event.startDateTime
    ? formatStart(event.startDateTime, event.isAllDay === true)
    : "";

  const notifTitle = `${actorName}님이 ${notificationTitle}`;
  const notifBody = when ? `${title} · ${when}` : title;

  await admin.messaging().send({
    token: fcmToken,
    notification: {
      title: notifTitle,
      body: notifBody,
    },
    // 수신 기기가 백그라운드에서 캘린더/위젯 동기화를 돌리고, 알림 기록에 남기도록
    // 데이터 페이로드에 eventId/title/body를 함께 보낸다.
    data: {
      type: "event_sync",
      eventId: eventId ?? "",
      title: notifTitle,
      body: notifBody,
    },
    android: { priority: "high" },
  });
}

exports.onEventCreated = onDocumentCreated("events/{eventId}", async (event) => {
  const data = event.data?.data();
  if (!data) return;
  const title =
    data.status === "proposed" ? "일정을 제안했어요" : "일정을 등록했어요";
  await sendToPartner(data, event.params.eventId, data.createdByUid ?? "", title);
});

exports.onEventUpdated = onDocumentUpdated("events/{eventId}", async (event) => {
  const before = event.data?.before?.data();
  const after = event.data?.after?.data();
  if (!before || !after) return;
  const actorUid = after.lastEditorUid ?? after.createdByUid ?? "";

  // 제안 수락: proposed → confirmed 전이는 다른 필드 변경 없어도 발송
  if (before.status === "proposed" && after.status === "confirmed") {
    await sendToPartner(after, event.params.eventId, actorUid, "제안을 수락했어요");
    return;
  }

  if (!hasMeaningfulChange(before, after)) return;
  await sendToPartner(after, event.params.eventId, actorUid, "일정을 수정했어요");
});
