# 아침 브리핑 알림 설계

2026-07-17 승인. 매일 아침 설정 시각에 "오늘의 일정" 요약 로컬 알림. 일정 없는 날 스킵. 서버 불필요 (7일 선스케줄).

## 방식

앱 실행/이벤트 변화 시(기존 `alarmSyncProvider` 시점 편승) + 브리핑 설정 변경 시, **오늘부터 7일치** 브리핑 알림을 재스케줄:
1. 기존 브리핑 알림 전부 취소 (ID = `'briefing-' + yyyyMMdd` 해시, 날짜 기반 고정)
2. 각 날짜 D에 대해 `expandRecurringForRange(events, D, D)` + `eventsForDay`로 그날 일정 계산
3. 일정 0건이면 스킵. 있으면 D의 설정 시각(기본 08:00)에 zonedSchedule (이미 지난 시각이면 스킵)

## 설정 (기기별 — SharedPreferences)

- 키: `briefing_enabled` (bool, 기본 false), `briefing_hour`/`briefing_minute` (int, 기본 8/0)
- 설정 화면 "기념일 관리" 아래 섹션:
  - SwitchListTile "아침 브리핑" — 켜면 즉시 스케줄, 끄면 브리핑 취소
  - 켜진 상태에서만 시간 행 노출 (탭 → TimePicker) — 변경 시 재스케줄
- 부부 각자 폰별 독립 설정.

## 알림 내용 (순수 함수 `briefingBody(List<EventModel> dayEvents)`)

- 제목: `오늘의 일정 N건`
- 본문: 최대 3건, `아이콘 제목 (HH:mm)` 콤마 연결. 종일은 `(종일)`. 3건 초과 시 ` 외 N건` 접미.
  예: `🎂 55 (22:15), gg (22:15) 외 1건`
- 정렬은 `eventsForDay` 결과 순서(종일 우선, 시간순) 그대로.

## 알림 채널

별도 채널 `briefing_channel` ("아침 브리핑") — 일정 알람 채널과 분리, 기기에서 개별 제어.

## 구현 지점

- `NotificationService`: `scheduleBriefings({required List<EventModel> events, required bool enabled, required int hour, required int minute})` + 내부 `cancelBriefings()`. `_supported` 가드 동일.
- `lib/services/briefing_prefs.dart`: SharedPreferences 읽기/쓰기 (enabled/hour/minute).
- `lib/utils/briefing_utils.dart`: `briefingBody` 순수 함수 (제목/본문 record 또는 클래스 반환).
- `calendar_provider.dart`: `alarmSyncProvider` 안에서 브리핑도 재스케줄 (prefs 읽어서).
- `settings_screen.dart`: 설정 UI.

## 에러/엣지

- 알림 권한 없음 → zonedSchedule 실패는 기존 알람과 동일하게 무시 (try/catch).
- 로그아웃 `cancelAll()` → 브리핑 포함 전체 취소 (기존 동작).
- 오늘 브리핑 시각이 이미 지남 → 오늘은 스킵, 내일부터.

## 테스트

- `briefingBody` 단위: 0건 null, 1건, 3건, 4건("외 1건"), 종일 표기, 이모지 prefix.
- 스케줄/설정 UI는 실기기 + 브라우저 수동 (알림 자체는 실기기만).

## 비범위

- FCM 서버 발송, 파트너별 원격 설정, D-Day 포함, 주말 제외 옵션.
