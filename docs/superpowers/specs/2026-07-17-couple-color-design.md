# 커플 색상 커스텀 설계

2026-07-17 승인. 설정에서 내 색상을 프리셋 12색 중 선택, 내가 만든 기존 일정 색도 일괄 변경.

## UI

- 설정 화면 "파트너 연결" 항목(연결됨 상태)의 색 점을 탭 가능하게 → "내 색상" 다이얼로그.
- 다이얼로그: Material 12색 그리드(4열), 현재 내 색에 체크 표시, 파트너가 쓰는 색은 비활성(탭 불가, 반투명).
- 자기 색만 변경 가능 (ownerColor/partnerColor 중 내 역할 필드).
- couple null 또는 미연결이면 색 점 없음(기존 UI 그대로) — 진입 불가.

## 팔레트 (`lib/theme/couple_palette.dart` 상수)

red400(0xFFEF5350), pink300(0xFFF06292), purple400(0xFFAB47BC), deepPurple400(0xFF7E57C2), indigo400(0xFF5C6BC0), blue400(0xFF42A5F5), teal400(0xFF26A69A), green400(0xFF66BB6A), amber600(0xFFFFB300), orange400(0xFFFFA726), brown400(0xFF8D6E63), blueGrey400(0xFF78909C).

## 저장 흐름 (`FirestoreService.updateMyColor`)

`Future<void> updateMyColor({required CoupleModel couple, required String myUid, required int color})`:
1. `couples/{coupleId}`에 내 역할 필드(`ownerUid == myUid` ? `ownerColor` : `partnerColor`)를 `set(..., merge: true)`.
2. `events` where `coupleId == couple.coupleId && createdByUid == myUid` 조회 → batch로 `color` 필드 일괄 update (500개 단위 chunk).

반영은 기존 스트림 경유 자동 (couples 스트림 → 설정 점/새 이벤트 색, events 스트림 → 그리드/시트/위젯).

## 순수 로직 (테스트 대상)

`String myColorField(CoupleModel couple, String myUid)` → `'ownerColor'` | `'partnerColor'`. (owner면 ownerColor, 아니면 partnerColor)

## 에러 처리

- batch 실패 → 스낵바 "일부 일정 색이 변경되지 않았습니다" (couple 색 변경 자체는 이미 반영).
- 다이얼로그에서 현재 색 재선택 → no-op 닫기.

## 테스트

- `myColorField` 단위 테스트 (owner/partner 역할).
- 다이얼로그/batch는 chrome E2E 수동.

## 비범위

- 자유 컬러피커, 상대 색 변경, 이벤트별 개별 색.
