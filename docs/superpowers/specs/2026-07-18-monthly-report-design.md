# 월간 커플 리포트 설계

2026-07-18. 이번 달 활동 요약 화면. 서버 불필요 — 기존 events/wishes 스트림으로 클라이언트 집계.

## 통계 항목 (`MonthlyReport` — 순수 함수 산출)

`MonthlyReport buildMonthlyReport({required List<EventModel> events, required List<WishModel> wishes, required DateTime month, required String myUid})`:

- `totalEvents`: 해당 월 일정 수 (반복 회차 전개 포함 — `expandRecurringForRange(월 1일~말일)` 후 그 달에 시작하는 occurrence 수)
- `myEvents` / `partnerEvents`: createdByUid 기준 내/상대 작성 수 (전개 회차 포함)
- `allDayEvents`: 종일 일정 수
- `topIcon`: 가장 많이 쓴 이모지 (String?, 동률이면 먼저 나온 것, 없으면 null)
- `wishesDone` / `wishesTotal`: 위시 완료/전체 (월 무관 누적 — 완료 시각 미저장이므로)

## UI (`lib/screens/report/report_screen.dart`, 라우트 `/report`)

- 진입: 설정 화면 "기념일 관리" 아래 "월간 리포트" 타일.
- 앱바에 `yyyy년 M월` + 좌우 화살표로 월 전환 (로컬 상태).
- 본문 카드 3개:
  1. **일정**: "이번 달 일정 N건" 크게, 아래에 "나 N · 상대 N · 종일 N"
  2. **최애 이모지**: topIcon 크게 표시 (없으면 카드 숨김)
  3. **위시리스트**: "완료 N / 전체 N" + 진행 바(LinearProgressIndicator)
- couple 미연결 → "파트너 연결 후 사용할 수 있습니다".

## 테스트

- `buildMonthlyReport` 단위: 빈 달 0값, 월 경계(전월/익월 제외), 반복 전개 포함 카운트, 내/상대 분류, 종일 수, topIcon 동률/없음, 위시 집계.

## 비범위

- 서버 집계, 월별 위시 완료 추적, 이미지 공유/내보내기.
