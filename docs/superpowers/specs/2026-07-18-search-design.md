# 일정 검색 설계

2026-07-18. 제목/메모 검색 + 작성자 필터. 클라이언트 검색 (기존 events 스트림).

## 순수 함수 (`lib/utils/search_utils.dart`)

```dart
enum SearchFilter { all, mine, partner }

List<EventModel> searchEvents({
  required List<EventModel> events,   // 마스터 목록 (반복 전개 안 함)
  required String query,
  required SearchFilter filter,
  required String myUid,
});
```

- query 공백 트림 후 빈 문자열이면 빈 리스트 반환.
- 대소문자 무시 substring 매칭: `title` 또는 `description`.
- filter: mine = createdByUid == myUid, partner = != myUid, all = 전부.
- 정렬: startDateTime desc (최신 먼저).

## UI (`lib/screens/search/search_screen.dart`, 라우트 `/search`)

- 진입: 캘린더 헤더 checklist 아이콘 왼쪽에 검색 아이콘.
- 앱바에 TextField (autofocus, hint "일정 검색", clear 버튼).
- 아래 필터 칩 3개 (전체/나/상대, ChoiceChip 단일 선택, 기본 전체).
- 결과: ListTile — leading 색 점, title "아이콘 제목"(이모지 prefix 규칙 기존과 동일), subtitle "yyyy.MM.dd (E)" + 반복이면 · 반복 표시. 탭 → 상세 (`EventDetailArgs(event, occurrenceDate: 시작일)`).
- 빈 쿼리: 중앙 "제목이나 메모로 검색하세요". 결과 0: "검색 결과가 없습니다".

## 테스트

- searchEvents: 빈 쿼리, 제목/메모 매칭, 대소문자 무시, 필터 3종, 정렬 desc.

## 비범위

- 반복 회차 단위 결과, 위시 검색, 날짜 범위 필터, 서버 검색.
