# Orca(ADE) 활용 가이드 — CoyHouseCalender

Orca에서 이 레포로 병렬 에이전트 작업하는 방법. 레포 경로: `C:\Users\pup99\StudioProjects\test_calender`

## 사전 조건 (중요)

1. **작업 시작 전 현재 WIP 커밋 필수.** worktree는 커밋에서 분기하므로 uncommitted 변경(theme/, month_grid 등)은 새 worktree에 없다.
2. worktree 생성 직후 그 worktree 터미널에서 세팅 스크립트 실행:
   ```powershell
   powershell -ExecutionPolicy Bypass -File C:\Users\pup99\StudioProjects\test_calender\scripts\setup-worktree.ps1
   ```
   gitignore된 `android/local.properties`, `android/key.properties` 복사 + `flutter pub get` 수행.
   (Orca 설정에 worktree setup script 항목이 있으면 위 명령을 등록해두면 자동화됨.)

## 1. 병렬 작업 분리 (worktree 3개)

Orca에서 worktree 3개 생성 (base: master), 각각 Claude Code 에이전트 연결.

| Worktree 브랜치 | 담당 | 첫 프롬프트 예시 |
|---|---|---|
| `fix/samsung-sync` | 삼성캘린더 동기화 버그 | "lib/services의 삼성캘린더 동기화 코드를 점검하고 [증상]을 수정해줘. CLAUDE.md 참고." |
| `feat/theme-ui` | 테마/UI 정리 | "lib/theme/과 month_grid.dart 기반으로 캘린더 화면 UI를 다듬어줘." |
| `test/coverage` | 테스트 작성 | "lib/services와 lib/providers에 단위 테스트를 작성해줘. flutter test로 검증." |

### 주의 (직렬화 규칙)
- **코드 작업만 병렬.** `flutter run`/빌드는 한 번에 하나 — 동시 빌드는 Windows에서 디스크/CPU 압박.
- **실기기(Z플립5) 테스트는 한 worktree씩.** 기기 하나, 앱 설치 슬롯 하나.
- 완료된 브랜치만 master에 merge. merge 후 다른 worktree는 `git rebase master`.

## 2. 팬아웃: 같은 프롬프트 → 여러 에이전트 → 비교

UI/설계처럼 정답 없는 작업에 사용. Orca의 fan-out으로 같은 프롬프트를 2~3개 에이전트에 뿌리고 결과 diff 비교, 승자 merge.

프롬프트 템플릿:
```
lib/screens/calendar/month_grid.dart의 월간 그리드 디자인을 개선해줘.
제약: table_calendar 의존 유지, lib/theme/ 토큰 사용, 이벤트 색상은 ARGB int.
완료 후 flutter analyze 통과 확인.
```

비교 기준: `flutter analyze` 통과 → diff 크기(작을수록 좋음) → chrome에서 실제 렌더링 확인.
**팬아웃 중에는 다른 병렬 작업 멈추기** — worktree 3~4개가 동시에 pub get/analyze 돌면 느려짐.

## 3. Chromium 엘리먼트 피커 (UI 피드백 루프)

1. 검증하려는 worktree **하나만** 골라 `flutter run -d chrome` (CLAUDE.md 권장 개발 방식 — 알림 제외 전 기능 동작).
2. Orca 내장 브라우저로 `http://localhost:<포트>` 열기 (flutter run 출력에 포트 표시됨).
3. UI 요소 클릭 → HTML/CSS/스크린샷이 에이전트 프롬프트에 자동 삽입 → "이 부분 이렇게 바꿔줘".
4. Flutter web은 CanvasKit 렌더러면 DOM이 캔버스 하나라 요소 선택이 무의미함. 피커 쓰려면 HTML 렌더러로 실행:
   ```
   flutter run -d chrome --web-renderer html
   ```
   (렌더러 옵션이 SDK에서 제거된 버전이면 스크린샷 영역 선택만 활용.)

### 알려진 제약 (CLAUDE.md 준수)
- Firebase Auth는 Windows 데스크톱 미동작 — chrome 또는 실기기만.
- 위젯/알림 기능은 chrome에서 테스트 불가 — 실기기 직렬 테스트.

### 디버그 모드는 탭 하나만 (중요)
`flutter run`(debug)은 **첫 접속 탭이 디버그 서비스를 독점**한다. 두 번째 탭부터는 영원히 빈 화면(흰 화면). 실제 겪은 증상: Orca 탭 + Chrome 탭 동시에 열었더니 전부 빈 화면.

규칙:
- 디버그 서버는 브라우저 탭 **하나만** 연결 (Orca 탭이면 Orca 탭만).
- 빈 화면 나오면: 다른 탭 전부 닫기 → flutter 프로세스 재시작 → 보려는 탭 하나만 리로드 (첫 클라이언트가 되게).
- 여러 탭/사람이 동시에 봐야 하면 `flutter run -d web-server --release` (핫리로드 포기).

### Orca CLI로 내장 브라우저 조작
```powershell
$orca = "$env:LOCALAPPDATA\Programs\orca\resources\bin\orca.exe"
& $orca tab create --url http://localhost:8080   # 탭 열기
& $orca tab list --json                          # 탭 목록
& $orca reload                                   # 활성 탭 리로드
& $orca screenshot --format png --json           # 스크린샷 (base64)
& $orca eval --expression "document.title"       # JS 실행
```
참고: `tab create`가 `runtime_unavailable` 에러를 내도 실제로는 탭이 생기는 경우 있음 — `tab list`로 확인하고 중복 탭은 닫기 (중복 탭 = 디버그 세션 충돌 원인).
