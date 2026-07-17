# 데이트 위시리스트 설계

2026-07-17. 하고 싶은 것/가고 싶은 곳 보관함. 날짜가 잡히면 일정 폼으로 승격.

## 데이터 모델

top-level 컬렉션 `wishes/{wishId}` (events 패턴 동일):

```
id, coupleId, createdByUid, title, memo(String?), done(bool, 기본 false), createdAt
```

`WishModel` + fromMap/toMap. Firestore 규칙에 events와 동일 패턴의 wishes 블록 추가 후 배포:
- read/update/delete: `resource.data.coupleId == myCoupleId()`
- create: `request.resource.data.coupleId == myCoupleId() && createdByUid == request.auth.uid`

## 서비스/프로바이더

- `FirestoreService`: `wishesStream(coupleId)` (createdAt desc 정렬), `addWish(WishModel)`, `updateWish(WishModel)`, `deleteWish(id)` — events CRUD 패턴 그대로.
- `wishesStreamProvider` (calendar_provider, eventsStreamProvider 패턴).

## UI

- **진입**: 캘린더 헤더 상단 Row의 설정 아이콘 왼쪽에 위시리스트 아이콘(`Icons.favorite_border` 대신 `Icons.checklist` — 하트는 연결 상태로 이미 사용) → `/wishlist` 라우트.
- **화면** (`lib/screens/wishlist/wishlist_screen.dart`):
  - 목록: 체크박스(done 토글, 완료 시 취소선) + 제목/메모 + trailing: 캘린더 아이콘("일정으로"), 삭제 아이콘(확인 다이얼로그).
  - 미완료 먼저, 각 그룹 내 최신순.
  - FAB 추가 → 다이얼로그 (제목 필수, 메모 선택).
  - 항목 탭 = 수정 다이얼로그.
  - 빈 목록: "하고 싶은 것을 적어보세요".
- **일정 승격**: 캘린더 아이콘 탭 → `/event/new`로 이동하되 제목 프리필. `EventFormScreen`에 `initialTitle` 파라미터 추가, 라우트 extra를 `{DateTime? date, String? title}` 형태로 확장 (기존 DateTime extra 하위호환). 위시 항목은 그대로 둠 (완료 처리는 수동 체크).

## 에러/엣지

- couple null → 위시 화면 진입 시 안내 문구.
- 파싱 실패 문서 스킵 (events 스트림과 동일하게 fromMap 실패 시 해당 문서 제외).

## 테스트

- WishModel 직렬화 왕복 + memo null + done 기본값 (단위).
- 정렬(미완료 우선/최신순) 순수 함수 단위 테스트.
- UI는 브라우저 E2E.

## 비범위

- 위시 완료 시 자동 일정 연결, 사진 첨부, 카테고리, 파트너 알림.
