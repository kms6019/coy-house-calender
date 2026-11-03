const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { setGlobalOptions } = require("firebase-functions/v2");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");

admin.initializeApp();

// 과금 가드: 인스턴스 상한 + 최소 메모리. 함수는 events 에 쓰지 않음(무한 트리거 불가) —
// 쓰는 곳은 users/{uid}/notificationHistory 뿐이다.
setGlobalOptions({
  region: "asia-northeast3",
  maxInstances: 2,
  memory: "256MiB",
});

// 구글 Places API 키는 앱(APK)에 넣지 않고 서버 시크릿으로만 둔다. APK 에서 키를
// 뽑아 남용해도 과금되지 않도록, 검색은 로그인한 사용자만 이 함수를 거쳐서 한다.
const placesApiKey = defineSecret("PLACES_API_KEY");

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
  "place",
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

const MAX_HISTORY = 50;

async function recordHistory(db, uid, entry) {
  const col = db.collection("users").doc(uid).collection("notificationHistory");
  await col.add({
    ...entry,
    receivedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  const old = await col
    .orderBy("receivedAt", "desc")
    .offset(MAX_HISTORY)
    .get();
  if (old.empty) return;
  const batch = db.batch();
  old.docs.forEach((d) => batch.delete(d.ref));
  await batch.commit();
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
  const actorName = (actorSnap.data()?.displayName ?? "").trim() || "상대방";
  const title = (event.title ?? "").trim() || "(제목 없음)";
  const when = event.startDateTime
    ? formatStart(event.startDateTime, event.isAllDay === true)
    : "";

  const notifTitle = `${actorName}님이 ${notificationTitle}`;
  const notifBody = when ? `${title} · ${when}` : title;

  // 알림 기록은 서버가 남긴다. 수신 기기의 백그라운드 핸들러는 삼성 배터리
  // 최적화 등으로 안 도는 경우가 많아 기록이 계속 누락됐다.
  await recordHistory(db, partnerUid, {
    title: notifTitle,
    body: notifBody,
    eventId: eventId ?? "",
  });

  const fcmToken = partnerSnap.data()?.fcmToken ?? "";
  if (!fcmToken) return;

  await admin.messaging().send({
    token: fcmToken,
    notification: {
      title: notifTitle,
      body: notifBody,
    },
    // 수신 기기가 백그라운드에서 캘린더/위젯 동기화를 돌리도록 데이터 페이로드를 함께 보낸다.
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

// Places API (New) 자동완성 응답 → 앱이 쓰는 장소 목록.
// Place Details 는 부르지 않는다 — 이름·주소·placeId 는 자동완성 결과로 충분하고,
// 상세 조회까지 하면 건마다 과금 단계가 올라간다.
function toSuggestions(json) {
  const suggestions = [];
  for (const s of json?.suggestions ?? []) {
    const p = s?.placePrediction;
    if (!p) continue; // queryPrediction(검색어 추천)은 장소가 아니라서 버린다
    const placeId = (p.placeId ?? "").trim();
    const name = (
      p.structuredFormat?.mainText?.text ?? p.text?.text ?? ""
    ).trim();
    if (!placeId || !name) continue;
    // 국내 주소는 전부 "대한민국 " 으로 시작해서 일정 화면·삼성캘린더에서 군더더기다
    const address = (p.structuredFormat?.secondaryText?.text ?? "")
      .trim()
      .replace(/^대한민국\s+/, "");
    suggestions.push(address ? { placeId, name, address } : { placeId, name });
  }
  return { suggestions };
}

exports.searchPlaces = onCall({ secrets: [placesApiKey] }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "로그인이 필요해요");
  }
  const input =
    typeof request.data?.input === "string" ? request.data.input.trim() : "";
  if (input.length < 1 || input.length > 100) {
    throw new HttpsError("invalid-argument", "검색어는 1~100자여야 해요");
  }
  // 세션 토큰: 자동완성 여러 번을 한 세션으로 묶어 과금 단위를 줄인다
  const token = request.data?.sessionToken;
  const sessionToken =
    typeof token === "string" && token.length > 0 && token.length <= 64
      ? token
      : undefined;

  const res = await fetch("https://places.googleapis.com/v1/places:autocomplete", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Goog-Api-Key": placesApiKey.value(),
    },
    body: JSON.stringify({
      input,
      languageCode: "ko",
      regionCode: "kr",
      ...(sessionToken ? { sessionToken } : {}),
    }),
  });
  if (!res.ok) {
    const body = (await res.text()).slice(0, 500);
    console.error(`[searchPlaces] Places 응답 ${res.status}: ${body}`);
    throw new HttpsError("unavailable", "장소 검색을 할 수 없어요");
  }
  return toSuggestions(await res.json());
});
