# AGENTS.md — Codex 오케스트레이션 인수인계 (2026-07-18)

Claude Code에서 Codex로 오케스트레이션 이관. **CLAUDE.md를 먼저 읽을 것** (아키텍처·명령어·Known Issues 전부 거기 있음). 이 문서는 이관 시점 상태 + 운영 절차.

## 현재 상태 (2026-07-18 저녁 기준)

- 브랜치: master, 전부 push됨. 테스트 **107/107**, `flutter analyze`는 기존 info 2건뿐 (event_detail use_build_context_synchronously — 무시 중)
- 백로그(옵시디언 `C:/Users/PUP99/Documents/HousePC/1. Projects/CoyHouseCalender/04. 기능 아이디어 백로그.md`) **전 항목 완료**
- Firebase **Blaze 전환 완료** (예산 알림 설정 안내됨). 과금 가드: functions maxInstances 2 / 256MiB / 이미지 정리 1일 / 함수는 Firestore 쓰기 없음
- 배포된 서버 리소스: Cloud Functions `onEventCreated`/`onEventUpdated` (asia-northeast3), firestore.rules, storage.rules (버킷 생성됨)

## 오늘 구현된 기능 (전부 커밋·배포 완료)

| 기능 | 핵심 파일 |
|---|---|
| 파트너 FCM 푸시 (등록/수정/제안/수락 문구) | `functions/index.js`, `lastEditorUid` (firestore_service.updateEvent) |
| 같이 일정 ❤️ | `EventModel.isShared` |
| 제안→수락/거절 📩 | `EventModel.status` proposed/confirmed, event_detail 수락/거절 버튼 |
| 월간 위젯 5×6 + 셀별 이벤트 제목 | `CalendarMonthWidgetProvider.kt`, `widget_month_utils.dart` (titlesByDay), Spannable |
| 사진/한줄 후기 | `EventModel.reviewText/reviewPhotoUrl`, Storage `reviews/{eventId}.jpg` |
| 월 스와이프 애니메이션 + 기념일 🎉 표시 | calendar_screen `_MonthPager`(PageView), `anniversaryEventsForMonth` (dday_utils) |
| 삼성캘린더 미러 동기화 (상대 일정 포함) | `SamsungCalendarSyncService.syncAll`, `deviceCalendarSyncProvider` |
| 푸시 수신 백그라운드 동기화 | functions data `{type: 'event_sync'}` → main.dart `_firebaseMessagingBackgroundHandler` |

## 미검증 — 실기기 확인 대기 (최우선)

두 폰(남편/와이프) 모두 최신 APK 설치 후:
1. 푸시 3종 (등록/제안/수락) 수신
2. 월간 위젯 5×6 렌더링 (기존 위젯 제거 후 재추가 필요)
3. 사진 후기 업로드/표시
4. 백그라운드 동기화 (앱 닫고 상대가 일정 등록 → 삼성캘린더 반영)
5. 기기 캘린더 가져오기 (설정 → 기기 캘린더 가져오기)

문제 발생 시: `firebase functions:log --project coy-house-calender`, adb logcat.

## 배포 절차

- **APK 링크 배포**: `flutter build apk --release` → `build\app\outputs\flutter-apk\app-release.apk`를
  1. `%LOCALAPPDATA%\Temp\claude\...\scratchpad\apk-share\coyhouse.apk` (기존 폴더 아무데나 새로 만들어도 됨) 로 복사
  2. 그 폴더에서 `python -m http.server 8090 --bind 0.0.0.0` → 링크 `http://172.30.1.17:8090/coyhouse.apk` (PC IP 고정 아님 — `ipconfig`로 확인)
  3. 바탕화면 `CoyHouseCalendar-v1.0.0.apk` + zip도 갱신 (카톡 전달용, .apk는 카톡 차단이라 zip)
- **Functions**: `firebase deploy --only functions --project coy-house-calender --force` (--force는 cleanup policy 프롬프트 회피)
- **Rules**: `--only firestore` / `--only storage`
- 서명: `android/key.properties` + `android/app/upload-keystore.jks` (gitignored — **백업 필수, 분실 시 업데이트 불가**)

## 오케스트레이션 규칙 (검증된 방식)

- 병렬 세션 간 **쓰기 파일 완전 분리** (겹치면 사고)
- `flutter test`는 **한 세션만** 실행 (동시 실행 시 세션 사망 사례 있음). 구현 세션엔 test/analyze/git 금지시키고 컨트롤러가 검증
- **git 커밋은 컨트롤러가 수행** (작업 세션은 커밋 생략 잦음)
- 브리프는 파일로 전달, 인터페이스 계약(시그니처·키 이름)을 브리프에 고정
- 워크플로: 스펙(docs/superpowers/specs/) → 구현 → analyze+test → 커밋 → 필요 시 functions 배포 → APK 갱신
- 사용자 스타일: 추천안 제시하고 자동 결정, ~3개 작업마다 보고, 한국어

## 함정 (CLAUDE.md Known Issues 외 추가분)

- functions 푸시: onUpdate는 `MEANINGFUL_FIELDS` 변경 시만 발송. 후기(reviewText) 저장은 의도적으로 푸시 안 보냄. proposed→confirmed 전이는 필드 변경 없어도 "수락" 푸시
- `EventModel.copyWith`는 null 병합 — icon/repeat 해제는 `copyWithIcon`/`copyWithRepeat` 사용
- `deviceCalendarSyncProvider`: coupleId 빈 값이면 스킵 (로그아웃 시 기기 캘린더 전체 삭제 방지 가드 — 제거 금지)
- 반복 일정은 판정식이 아니라 **범위 전개** (`expandRecurringForRange`) — occurrence 복사본 id는 마스터와 동일
- 위젯: plain `<View>` 금지, HomeWidgetPreferences prefix 없음 (CLAUDE.md 참조)
- PowerShell 5.1은 BOM 없는 한글 .ps1 깨뜨림 — UTF-8 BOM으로 저장
- Orca 브라우저 로그인 = **와이프 실계정** — E2E로 만든 테스트 데이터는 즉시 삭제

## 다음 후보 (사용자와 논의)

- 실기기 검증에서 나온 버그 수정 (최우선)
- 반복 일정 v2: 이 회차만 수정, 격주, 삼성캘린더 EXDATE
- 후기 모아보기(추억 앨범) 화면, 위젯 탭 → 앱 실행 인텐트
- 별도 테스트 계정 만들어 E2E와 실데이터 분리
