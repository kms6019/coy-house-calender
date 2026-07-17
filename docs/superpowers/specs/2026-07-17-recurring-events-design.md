# 반복 일정 기능 설계

2026-07-17 승인. 이벤트에 매일/매주/매월/매년 반복 규칙 추가. 마스터 이벤트 1개 + 조회 시 전개 방식.

## 데이터 모델

`events/{eventId}` 문서에 필드 3개 추가 (기존 문서는 필드 없음 = 반복 없음으로 하위호환):

```
repeat: string          // 'none' | 'daily' | 'weekly' | 'monthly' | 'yearly' (기본 'none')
repeatUntil: Timestamp? // 반복 종료일(포함). null = 무한
excludedDates: [Timestamp] // '이 회차만 삭제'된 날짜(자정 정규화). 기본 []
```

`EventModel`에 대응 필드: `repeat` (enum `RepeatRule { none, daily, weekly, monthly, yearly }`), `repeatUntil: DateTime?`, `excludedDates: List<DateTime>`. `copyWith` 확장. 파싱 시 알 수 없는 repeat 값은 `none` 취급.

## Occurrence 판정 (순수 함수, `lib/utils/event_utils.dart` 확장)

`bool occursOn(EventModel event, DateTime day)`:
- `repeat == none` → 기존 날짜 비교 로직 그대로
- 공통 전제: `day`가 시작일(자정 기준) 이전이면 false, `repeatUntil` 이후면 false, `excludedDates`에 있으면 false
- `daily`: 시작일 이후 매일 true
- `weekly`: `day.weekday == start.weekday`
- `monthly`: `day.day == start.day` (해당 월에 없는 날짜면 자연 스킵 — 예: 31일 시작이면 2월엔 안 뜸)
- `yearly`: `day.month == start.month && day.day == start.day` (2/29는 평년 스킵)

`eventsForDay()`가 `occursOn`을 사용하도록 변경. 반복 이벤트의 표시 시각은 마스터의 시각을 해당 날짜로 옮긴 것 (기간 이벤트: start~end 시간 길이 유지, 종일은 종일).

캘린더 그리드·일별 시트·홈위젯은 모두 `eventsForDay` 경유이므로 자동 반영.

## 수정/삭제 시맨틱

- **수정**: 전체 단위만. 마스터 문서 수정 → 모든 회차 반영. (이 회차만 수정은 v2)
- **삭제**: `repeat == none`이면 기존 즉시 삭제 플로우. 반복 이벤트면 다이얼로그:
  - "이 일정만 삭제" → 마스터의 `excludedDates`에 해당 날짜 추가 (merge 아님 — events는 기존 update 패턴 사용)
  - "모든 반복 일정 삭제" → 문서 삭제
- 삭제 다이얼로그 진입점: 이벤트 상세 화면의 삭제. 어느 회차에서 열었는지 알아야 하므로 `/event/detail` 라우트의 `state.extra`를 `EventDetailArgs(event: EventModel, occurrenceDate: DateTime)` 클래스로 변경하고 호출부(일별 시트의 EventListTile 탭)에서 해당 날짜를 넘긴다.

## 알림

- 반복 이벤트는 **다음 도래 회차 1건**만 로컬 알림 스케줄 (`nextOccurrence(event, after)` 순수 함수로 계산).
- 재계산 시점: 앱 실행 시 + 이벤트 저장/삭제 시 (기존 알림 갱신 훅에 편승).
- flutter_local_notifications의 `matchDateTimeComponents` 반복은 사용하지 않음 (monthly/yearly 미지원이라 방식 통일).

## 삼성캘린더 동기화

- `buildDeviceCalendarEvent`에 device_calendar `RecurrenceRule` 매핑 추가:
  - daily/weekly/monthly/yearly → 해당 `RecurrenceFrequency`, interval 1
  - `repeatUntil` → `endDate`
- **v1 한계 (문서화)**: `excludedDates`는 삼성캘린더에 반영 안 됨 — 앱에서 "이 회차만 삭제"해도 삼성캘린더엔 그 회차가 남는다.

## UI

- **이벤트 폼**: "반복" 선택 (없음/매일/매주/매월/매년, 기본 없음). 반복 선택 시 "반복 종료일" 옵션 행 노출 (미설정 = 계속 반복, 설정 해제 가능).
- **상세 화면**: 반복 규칙 한 줄 표시 (예: "매주 반복 · 2026.12.31까지").
- **캘린더 그리드/리스트**: 반복 이벤트에 반복 아이콘(작은 repeat 아이콘) 표시.

## 에러/엣지

- 기존 문서(반복 필드 없음) → `repeat: none` 취급, 동작 변화 없음.
- `repeatUntil`이 시작일 이전이면 occurrence 없음 (폼에서 시작일 이전 선택 방지).
- 종일+기간(멀티데이) 이벤트의 반복은 시작일 기준으로만 전개 (기간 유지).

## 테스트

- `occursOn` 단위 테스트: 4주기 각각 × (시작 전/당일/이후 매칭·비매칭 요일/일, until 당일 포함·이후 제외, excludedDates 스킵, 31일→2월 스킵, 2/29 평년 스킵).
- `nextOccurrence` 단위 테스트: 각 주기 다음 회차, until 넘어가면 null, excluded 건너뛰기.
- `EventModel` 직렬화 왕복 + 반복 필드 없는 구 문서 파싱.
- UI/알림/sync는 chrome + 실기기 수동 확인.

## 비범위 (v2)

- 이 회차만 수정 (예외 인스턴스).
- 격주/횟수 지정/고급 규칙 (RRULE).
- excludedDates의 삼성캘린더 EXDATE 반영.
