# 기념일 D-Day 기능 설계

2026-07-17 승인. 커플 기념일 여러 개 등록, 캘린더 상단 + 안드로이드 홈위젯에 D-Day 표시.

## 데이터 모델

`couples/{coupleId}` 문서에 배열 필드 추가 (서브컬렉션 아님 — 기념일 수 10개 미만 전제, 기존 `coupleStreamProvider` 재사용):

```
anniversaries: [
  {
    id: string,        // UUID
    title: string,     // "처음 만난 날", "결혼기념일"
    date: Timestamp,   // 기준일
    type: string,      // "countUp" | "annual"
  }
]
```

- `countUp`: 기준일부터 경과일 카운트업. 표시 `D+n` (기준일 당일 = D+1).
- `annual`: 매년 반복. 다음 도래일까지 `D-n`, 당일 `D-Day`.
- 쓰기는 기존 패턴대로 `set(..., SetOptions(merge: true))`, 배열 전체 교체 방식.

## Dart 모델

`AnniversaryModel`: `id, title, date, type` + `fromMap`/`toMap`. `CoupleModel`에 `anniversaries` 리스트 필드 추가 (파싱 실패 항목은 개별 스킵).

D-Day 계산 로직 (`lib/utils/` 내 순수 함수):
- `dDayLabel(AnniversaryModel, DateTime now)` → "D+812", "D-23", "D-Day"
- annual 다음 도래일: 올해 도래일 지났으면 내년. 2/29는 평년 2/28로 처리.
- 날짜 비교는 시각 무시(자정 기준).

## UI

### 캘린더 상단 칩 줄
- `calendar_screen.dart` 상단에 가로 스크롤 칩 줄.
- 칩 텍스트: `{title} {dDayLabel}`.
- 정렬: annual 도래 임박순 → countUp 뒤에.
- 기념일 0개면 위젯 자체 미표시.

### 기념일 관리 화면
- 설정 화면에 "기념일 관리" 항목 추가 → 신규 화면 (라우트 추가).
- 목록 + FAB 추가. 항목 탭 = 수정, 항목 우측 삭제 아이콘 = 삭제(확인 다이얼로그).
- 입력 폼: 제목(필수), 날짜(DatePicker), 타입(D+ 카운트업 / 매년 반복 선택).

## 홈위젯

- `widget_service.dart`: 대표 countUp 1개(가장 오래된 기준일) + 도래 임박 annual 1개를 문자열로 SharedPreferences 기록 (예: `"처음 만난 날 D+812 · 생일 D-23"`).
- Kotlin `calendar_widget.xml` 레이아웃에 D-Day TextView 1줄 추가, `CalendarWidgetProvider.kt`에서 바인딩.
- 값 없으면 해당 줄 `GONE`.

## 에러 처리

- 배열 항목 파싱 실패 → 해당 항목만 스킵 (전체 실패 금지).
- `anniversaries` 필드 없는 기존 couples 문서 → 빈 리스트 취급.

## 테스트

- `dDayLabel` 단위 테스트: countUp 경과, annual 도래 전/당일/직후, 윤년 2/29, 연도 경계.
- `AnniversaryModel` 직렬화 왕복 테스트 + 불량 항목 스킵 테스트.
- UI/위젯은 chrome + 실기기 수동 확인.

## 비범위

- 기념일 알림 푸시 (파트너 알림 푸시 기능 보류와 동일 사유).
- 기념일별 색상/아이콘 커스텀.
