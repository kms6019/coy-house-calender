# 기기 캘린더 가져오기 설계

2026-07-18. 기기(구글/삼성) 캘린더의 일정을 골라 앱으로 가져온다. device_calendar 재사용, 서버 불필요.

## 흐름

설정 → "기기 캘린더 가져오기" → 권한 요청 → 기기 캘린더 목록 선택(드롭다운) → 기간 고정: 오늘부터 90일 → 이벤트 목록 (체크박스, 기본 전체 선택, **이미 가져온/중복 항목은 비활성+'있음' 표시**) → "N개 가져오기" 버튼 → `FirestoreService.addEvent` 반복 호출 → 완료 스낵바.

## 순수 로직 (`lib/utils/import_utils.dart`)

```dart
/// 기기 이벤트(제목/시작/종료/종일)를 앱 EventModel draft로 변환
EventModel deviceEventToDraft({
  required String title,
  required DateTime start,
  DateTime? end,
  required bool isAllDay,
  required String coupleId,
  required String myUid,
  required int color,
});

/// 중복 판정: 기존 events에 제목(트림)·시작시각(분 단위)·종일 여부가 같은 이벤트가 있으면 true
bool isDuplicateEvent(List<EventModel> existing, {required String title, required DateTime start, required bool isAllDay});
```

- draft: description null, repeat none, icon null, 알람 없음. color = 내 커플 색.
- 종일 이벤트 시각은 자정 정규화 후 비교.

## 화면 (`lib/screens/settings/import_screen.dart`, 라우트 `/settings/import`)

- device_calendar `DeviceCalendarPlugin` 직접 사용: `hasPermissions`/`requestPermissions`, `retrieveCalendars`, `retrieveEvents(calendarId, RetrieveEventsParams(startDate: 오늘, endDate: +90일))`.
- 권한 거부 → "캘린더 권한이 필요합니다" + 재요청 버튼.
- 캘린더 선택 드롭다운 (기본: 첫 캘린더). 읽기 전용 포함 전체 표시.
- 이벤트 리스트: CheckboxListTile — 제목 + `M월 d일 (E) HH:mm`(종일은 날짜만). 중복이면 비활성 + subtitle '이미 있음'.
- 하단 고정 버튼 "N개 가져오기" (선택 0이면 비활성) → 순차 addEvent → "N개 가져왔습니다" 스낵바 → pop.
- **삼성캘린더 재동기화 안 함**: addEvent 직접 호출 (syncEventCreate 미호출) — 기기에 이미 있는 일정이므로 중복 sync 방지.

## 진입점

설정 화면 "월간 리포트" 아래 "기기 캘린더 가져오기" 타일.

## 테스트

- `deviceEventToDraft` 필드 매핑 (종일/시간, 기본값들).
- `isDuplicateEvent`: 동일/제목 공백 차이/시각 분단위/종일 정규화/비중복.

## 비범위

- 반복 규칙 보존(기기 인스턴스를 개별 일정로), 자동 주기 동기화, 역방향 내보내기(이미 삼성 sync 존재).
