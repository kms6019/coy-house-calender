# Samsung 캘린더 동기화 설계

## 목표
CoyHouseCalender 앱에서 생성/수정/삭제한 이벤트를 기기의 네이티브 캘린더(삼성캘린더/AOSP CalendarProvider)에 자동 반영한다.

## 범위
- 방향: 앱 → 기기 캘린더 단방향. 기기 캘린더에서의 변경은 앱에 반영되지 않는다.
- 플랫폼: Android 전용. Windows/Chrome 빌드에서는 동작하지 않는다 (플랫폼 체크로 skip).
- 트리거: Firestore 이벤트 생성/수정/삭제 성공 직후 즉시 동기화.
- 대상 캘린더: 기기에 "CoyHouseCalender"라는 이름의 전용 로컬 캘린더를 자동 생성해서 그곳에만 기록한다. 사용자의 기존 개인 일정과 섞이지 않는다.

## 아키텍처

### 신규 패키지
- `device_calendar` (Android native CalendarProvider 접근)

### 신규 서비스: `lib/services/samsung_calendar_sync_service.dart`
- `ensureCalendarExists()` — "CoyHouseCalender" 캘린더가 이미 있는지 확인 후 없으면 생성. 생성된 캘린더 ID를 로컬에 캐시.
- `syncEventCreate(EventModel event)` — 기기 캘린더에 이벤트 생성, 반환된 device event id를 Firestore eventId와 매핑해 로컬 저장.
- `syncEventUpdate(EventModel event)` — 매핑에서 device event id 조회 후 업데이트. 매핑이 없으면 생성으로 처리 (fallback).
- `syncEventDelete(String eventId)` — 매핑에서 device event id 조회 후 삭제, 매핑 제거.

### 매핑 저장
- Firestore eventId ↔ device event id 매핑은 기기마다 다르므로 Firestore가 아닌 로컬(SharedPreferences, JSON 문자열 맵)에 저장한다. `widget_service.dart`가 이미 사용 중인 방식과 동일한 패턴.
- 키 예시: `samsung_calendar_event_map` → `{"firestoreEventId": "deviceEventId", ...}`
- 전용 캘린더 ID 캐시 키: `samsung_calendar_id`

### 트리거 지점
- `event_form_screen.dart`의 이벤트 생성/수정 완료 콜백, `event_detail_screen.dart`의 삭제 콜백 등 Firestore 쓰기가 성공한 직후에 sync 서비스 호출을 추가한다.
- 정확한 삽입 위치는 구현 단계에서 기존 코드 흐름 확인 후 결정.

### 권한
- AndroidManifest에 `READ_CALENDAR`, `WRITE_CALENDAR` 권한 추가.
- 최초 sync 시도 시 `device_calendar.requestPermissions()` 호출.
- 거부 시 조용히 skip — sync 기능만 비활성화되고 앱의 다른 기능(Firestore 기반 캘린더)은 정상 동작.

### 에러 처리
- sync 실패(퍼미션 없음, 캘린더 API 에러, 플랫폼 미지원 등)는 전부 try/catch로 격리한다.
- sync 실패가 Firestore 쓰기나 앱의 핵심 캘린더 기능에 영향을 주면 안 된다.
- 에러는 로그만 남기고 사용자에게 다이얼로그 등으로 노출하지 않는다.

## 테스트 방향
- 기기(Z플립5)에서 실제 실행 후: 이벤트 생성 → 삼성캘린더 앱에서 "CoyHouseCalender" 캘린더 아래 이벤트 확인 → 수정 → 반영 확인 → 삭제 → 반영 확인.
- 퍼미션 거부 시나리오: 거부해도 앱 크래시 없이 정상 동작하는지 확인.
- Windows/Chrome 빌드에서 sync 코드 경로가 예외 없이 skip되는지 확인.

## 비범위 (Out of scope)
- 기기 캘린더 → 앱 방향 동기화 (양방향 미지원)
- iOS 지원
- 사용자별 sync on/off 토글 UI (필요 시 추후 별도 작업)
