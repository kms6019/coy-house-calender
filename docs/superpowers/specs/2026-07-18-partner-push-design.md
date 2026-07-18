# 파트너 알림 푸시 설계

2026-07-18. 상대가 일정을 추가/수정하면 FCM 푸시로 알림.

## 목표

- 이벤트 **생성**: 상대에게 "OO님이 일정을 등록했어요 — 제목"
- 이벤트 **수정**: 상대에게 "OO님이 일정을 수정했어요 — 제목"
- 삭제 알림은 v1 제외 (onDelete에 행위자 정보 없음, 회차 삭제는 update로 처리되어 수정 알림으로 커버)

## 아키텍처

Cloud Functions v2 (Node 20) — Firestore 트리거:

```
events/{eventId} onCreate  → actor = createdByUid
events/{eventId} onUpdate  → actor = after.lastEditorUid ?? after.createdByUid
  → couples/{coupleId} 조회 → 상대 uid 결정 (ownerUid/partnerUid 중 actor 아닌 쪽)
  → users/{상대uid}.fcmToken 조회 → 없으면 종료
  → users/{actor}.displayName 조회 → FCM send
```

- 리전: asia-northeast3 (Firestore와 동일)
- **과금 가드**: maxInstances 2, 메모리 256MiB, 함수는 Firestore에 쓰기 안 함(무한 트리거 불가)
- 무료 할당: 월 2백만 호출 — 2인 사용 시 실질 0원

## 앱 변경

- `FirestoreService.updateEvent(event, {String? editorUid})` — `lastEditorUid` 필드 기록
- 호출부 2곳(event_form_screen, event_detail_screen)에서 현재 uid 전달
- FCM 수신 인프라(토큰 저장, 권한, 백그라운드 핸들러)는 기존 완비 — 변경 없음
- 포그라운드 수신은 무처리 유지 (앱 열려 있으면 캘린더가 실시간 갱신됨)

## 알림 페이로드

```json
{
  "notification": {
    "title": "민승님이 일정을 등록했어요",
    "body": "제목 · 7월 20일 (월) 14:00"  // 종일이면 "제목 · 7월 20일 (월) 종일"
  }
}
```

- displayName 빈 값이면 "상대방" 폴백

## 스킵 조건 (푸시 안 보냄)

- coupleId 없음 / couple 문서 없음 / isLinked false
- 상대 fcmToken 빈 값
- onUpdate에서 before/after의 title·description·start·end·isAllDay·color·icon·repeat 모두 동일 (updatedAt만 변경 등 무의미 쓰기)

## 배포 전제

- Blaze 플랜 (사용자 카드 등록) + Google Cloud 예산 알림 설정
- `firebase deploy --only functions`

## 테스트

- 함수 로직은 순수 헬퍼 분리(대상 uid 결정, 스킵 판정, 메시지 포맷) — Node 테스트 없이 코드 리뷰로 검증 (v1, 함수 1개 규모)
- E2E: 남편 폰에서 일정 생성 → 와이프 폰 푸시 수신 확인
