# 홈위젯 월간 미니 그리드 설계

2026-07-18. 기존 리스트 위젯은 유지, 월간 그리드 위젯을 별도로 추가 (사용자가 골라 배치).

## 데이터 흐름 (기존 패턴 동일)

Flutter `WidgetService.update()` → SharedPreferences(`HomeWidgetPreferences`, prefix 없음) → Kotlin RemoteViews.

새 키:
- `calendar_month_title`: "2026년 7월"
- `calendar_month_cells`: JSON 배열 42개 — `{"d":"15","ev":true,"today":false}` (d 빈 문자열 = 이웃 달 칸은 공백)

Dart 계산: 이번 달 1일이 속한 주의 일요일부터 42칸. 이벤트 있는 날 판정은 `expandRecurringForRange`로 그리드 범위 전개 후 날짜 셋 구성. 이웃 달 날짜는 d 빈 문자열 (표시 안 함).

## 위젯 UI (RemoteViews 제약 준수)

- plain `<View>` 금지 (구분선 필요 시 ImageView) — CLAUDE.md Known Issues
- 구조: 세로 LinearLayout
  1. 헤더 TextView (`widget_month_title`)
  2. 요일 행: 가로 LinearLayout, TextView 7개 (일~토, 일=빨강, 토=파랑)
  3. 6주 × 7일: 가로 LinearLayout 6개, 각각 TextView 7개, id `widget_cell_0`~`widget_cell_41`, layout_weight 1
- 셀 스타일 (Kotlin에서 설정):
  - 기본: 흰 배경 위 어두운 글자 (기존 위젯 배경과 통일)
  - 이벤트 있는 날: 핑크 굵은 색 텍스트 (`setTextColor`)
  - 오늘: `setBackgroundColor` 보라 + 흰 텍스트
- 위젯 탭 → 앱 실행 (기존 위젯과 동일 인텐트 패턴 있으면 따르고, 없으면 생략)

## 파일

1. `android/app/src/main/res/layout/calendar_month_widget.xml`
2. `android/app/src/main/res/xml/calendar_month_widget_info.xml` (minWidth 250dp, minHeight 180dp, updatePeriodMillis 0)
3. `android/app/src/main/kotlin/com/example/test_calender/CalendarMonthWidgetProvider.kt`
4. `AndroidManifest.xml` receiver 등록 (기존 CalendarWidgetProvider 항목 패턴 복제)
5. `lib/services/widget_service.dart` — 월 데이터 저장 + `HomeWidget.updateWidget(androidName: 'CalendarMonthWidgetProvider')` 추가 호출

## 테스트

- Dart: 42칸 생성 로직을 `lib/utils/widget_month_utils.dart`로 분리 — `buildMonthCells(DateTime today, Set<DateTime> eventDays)` → List<Map<String,Object>> 42개. 단위 테스트: 칸 수 42, 1일 위치, 오늘 플래그, 이웃 달 빈 문자열, 이벤트 플래그
- 실기기: 위젯 추가 후 렌더링 확인 (회색 "추가할 수 없습니다" = RemoteViews 위반 신호)
