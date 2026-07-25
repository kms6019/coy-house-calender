# 일정 충돌 경고 구현 계획

설계: `docs/superpowers/specs/2026-07-25-event-conflict-warning-design.md`

## Task 1: findConflicts 순수 함수 (TDD)

- [ ] **Step 1: 실패하는 테스트 작성** — `test/utils/conflict_utils_test.dart`
  설계의 테스트 목록 10개를 모두 작성한다.
- [ ] **Step 2: 테스트 실패 확인** — `flutter test test/utils/conflict_utils_test.dart`
  (컴파일 에러로 실패하는 것이 정상)
- [ ] **Step 3: 구현** — `lib/utils/conflict_utils.dart`
  종일 제외 → 자기 id 제외 → `expandRecurringForRange` 전개 → 열린구간 겹침 판정 → 시작시각 정렬
- [ ] **Step 4: 테스트 통과 확인** — `flutter test test/utils/conflict_utils_test.dart`
- [ ] **Step 5: 커밋** — `feat: 일정 충돌 판정 유틸 findConflicts`

## Task 2: 저장 시 경고 다이얼로그

- [ ] **Step 1: `_save()`에 충돌 검사 삽입** — `lib/screens/event/event_form_screen.dart`
  후보 EventModel 구성 후 Firestore 쓰기 직전에 `findConflicts` 호출.
  결과가 있으면 `AlertDialog` 표시, `취소` 시 return.
  async 경계마다 `mounted` 확인.
- [ ] **Step 2: 정적 분석** — `flutter analyze` (신규 경고 0건)
- [ ] **Step 3: 전체 테스트** — `flutter test` (전부 통과)
- [ ] **Step 4: 커밋** — `feat: 이벤트 저장 시 시간 충돌 경고 다이얼로그`

## Task 3: 수동 확인

- [ ] 설계 문서의 수동 확인 5항목을 실기기에서 확인하고 결과를 기록한다.
