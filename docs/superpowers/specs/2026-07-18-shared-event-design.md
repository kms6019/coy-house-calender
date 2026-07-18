# "같이" 일정 구분 설계

2026-07-18. 개인 일정 vs 함께하는 일정 구분, 함께 일정에 하트 뱃지.

## 데이터

- `EventModel.isShared` (bool, 기본 false) — Firestore `isShared` 필드
- 기존 문서(필드 없음) → false로 파싱
- `copyWith`에 `isShared` 파라미터 추가 (null 병합 방식 — false 해제는 폼에서 항상 명시값 전달로 해결)

## UI

- **폼** (event_form_screen): 반복 행 근처에 `SwitchListTile` — 제목 "함께하는 일정", secondary `Icon(Icons.favorite)` 핑크. 수정 시 기존 값 로드
- **리스트 타일** (event_list_tile): 제목 뒤 ' ❤️' suffix (isShared일 때만)
- **상세** (event_detail_screen): isShared면 정보 행 하나 추가 — 하트 아이콘 + "함께하는 일정"
- **월 그리드**: 변경 없음 (셀 공간 부족, v1 제외)

## 제외 (v1)

- 함께/개인 필터, 위젯 표시, 삼성캘린더 반영, 푸시 문구 구분

## 테스트

- event_model_test: fromMap 기본값 false, toMap 왕복, copyWith(isShared) 반영·미지정 시 보존
