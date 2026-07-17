# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**CoyHouseCalender** — 부부(2인) 공유 스마트 캘린더 Flutter 앱
- Firebase project: `coy-house-calender`
- Design doc path: `C:/Users/PUP99/Documents/HousePC/1. Projects/CoyHouseCalender/`

## Commands

```bash
# Run on physical device (Samsung Z플립5, device ID: R3CW70R1BCW)
flutter run -d R3CW70R1BCW

# WiFi 디버깅 (USB 불필요, 폰과 같은 WiFi + 무선 디버깅 ON 필요)
# adb 위치: D:\platform-tools-latest-windows\platform-tools\adb.exe
# 최초 1회 페어링: adb pair <IP:페어링포트> <코드> (폰 무선 디버깅 화면 참조)
# 이후: adb mdns services 로 자동 발견되면 flutter devices 에 wireless로 잡힘
flutter run -d adb-R3CW70R1BCW-AKYuPq._adb-tls-connect._tcp

# Run on Windows desktop
flutter run -d windows

# Run on Chrome (알림 제외 전 기능 동작 — 개발 권장)
flutter run -d chrome

# Build APK
flutter build apk

# Clean build (빌드 오류 시)
flutter clean && flutter pub get && flutter run -d R3CW70R1BCW

# Analyze
flutter analyze

# Test
flutter test
```

## Environment

- **Flutter SDK**: `C:\flutter_windows_3.41.6-stable\flutter\bin`
- **Pub Cache bin**: `C:\Users\PUP99\AppData\Local\Pub\Cache\bin`
- **JDK**: `C:\Program Files\Android\Android Studio\jbr`
- **Target device**: Samsung Z플립5 (SM-F731N), Android 16 (API 36)

## Architecture

### State Management & Data Flow

Riverpod providers form a dependency chain:

```
authStateProvider (Firebase Auth stream)
  └─► currentUserModelProvider (Firestore users/{uid} stream)
        └─► coupleStreamProvider (Firestore couples/{coupleId} stream)
        └─► eventsStreamProvider (Firestore events where coupleId stream)
              └─► eventsByDateProvider (Map<DateTime, List<EventModel>>)
              └─► selectedDayEventsProvider (filtered by selectedDateProvider)
```

- `authServiceProvider` → `AuthService` (singleton)
- `firestoreServiceProvider` → `FirestoreService` (singleton)
- `selectedDateProvider` → `StateProvider<DateTime>` for calendar date selection
- `routerProvider` → `GoRouter` with `_RouterNotifier` that listens to auth + user model changes

### Routing & Auth Guard

`app_router.dart` handles all redirect logic:
- Not logged in → `/login`
- Logged in, no coupleId → `/invite`
- Logged in, has coupleId → `/calendar`
- `/invite` auto-redirects to `/calendar` when coupleId appears (real-time via Riverpod listener)

Routes `/event/new`, `/event/detail`, `/event/edit` pass data via `state.extra` (typed cast).

### Firestore Schema

Collections:
- `users/{uid}`: `uid, email, displayName, coupleId, fcmToken, createdAt`
- `couples/{coupleId}`: `coupleId, ownerUid, partnerUid, inviteCode, isLinked, ownerColor, partnerColor, createdAt`
- `events/{eventId}`: `id, coupleId, createdByUid, title, description, startDateTime, endDateTime, isAllDay, color, hasAlarm, alarmMinutesBefore, createdAt, updatedAt`

Key patterns:
- Always use `set(..., SetOptions(merge: true))` instead of `update()` for user/couple doc writes (avoids missing-field errors)
- `FirestoreService.userStream()` falls back to a minimal `UserModel` if doc parsing fails
- Invite code = first 6 chars of UUID (uppercased, dashes stripped)
- Event color stored as ARGB int (`Color.toARGB32()`)

### Firebase Config

- **Firestore region**: asia-northeast3 (Seoul), test rules (30일)
- **Authentication**: Email/password only
- **Android SHA-1**: `D0:13:05:85:2F:8A:9C:1E:0F:6F:B1:A2:A4:19:93:CE:E2:96:37:D4`
- `android/app/google-services.json` must match the registered SHA-1

## Known Issues & Workarounds

| Issue | Fix |
|-------|-----|
| Windows에서 Firebase Auth 미동작 | Windows 실행 금지, 실기기로 테스트 |
| `flutterfire` CLI 인식 불가 | PowerShell에서 `$env:PATH += ";C:\flutter_windows_3.41.6-stable\flutter\bin"` 후 실행 |
| Windows 빌드 CMake 오류 | `windows/CMakeLists.txt`에 `set(CMAKE_POLICY_VERSION_MINIMUM 3.5)` 추가 |
| 홈위젯 레이아웃에 plain `<View>` 사용 금지 | RemoteViews 화이트리스트 위반 → 위젯 전체 회색("추가할 수 없습니다"). 구분선은 `<ImageView>` 사용 |
| 홈위젯 Kotlin에서 SharedPreferences 읽기 | `home_widget` 플러그인은 `HomeWidgetPreferences` 파일에 **prefix 없이** 저장. `FlutterSharedPreferences`/`flutter.` prefix 아님 |

## Implementation Progress

- [x] Phase 1: Firebase 연결, 기본 라우팅, 라우터
- [x] Phase 2: 로그인/회원가입, 초대코드 페어링, Firebase 연결
- [x] Phase 3: 캘린더 메인 화면 + 날짜별 이벤트 렌더링
- [x] Phase 4: 이벤트 CRUD
- [x] Phase 5: 알림 시스템 (로컬 + FCM)
- [x] Phase 6: 설정 화면, 로그아웃
- [x] Phase 7: 안드로이드 홈스크린 위젯

## Phase 7: Android Home Widget Plan

- Bridge: `home_widget` Flutter package
- Widget UI: Kotlin + XML (not Flutter widget rendering)
- Data flow: Firestore → Flutter app → SharedPreferences → widget

Files to create:
1. `lib/services/widget_service.dart` — writes data to SharedPreferences
2. `android/app/src/main/res/xml/calendar_widget_info.xml`
3. `android/app/src/main/res/layout/calendar_widget.xml`
4. `android/app/src/main/kotlin/.../CalendarWidgetProvider.kt`
5. Register in `android/app/src/main/AndroidManifest.xml`

Caveats:
- Widget updates only when app runs (foreground/background within ~30s)
- Widget shows cached data, not live Firestore stream
- `table_calendar` UI cannot be reused in widget (different rendering path)

## 코딩 가이드라인
Behavioral guidelines to reduce common LLM coding mistakes. Tradeoff: biases toward caution over speed. Use judgment for trivial tasks.

### 1. Think Before Coding
Before implementing: state assumptions explicitly, surface tradeoffs, present multiple interpretations if they exist, ask when unclear.

### 2. Simplicity First
Minimum code that solves the problem. No speculative features, no unnecessary abstractions, no unrequested configurability. If 200 lines could be 50, rewrite it.

### 3. Surgical Changes
Touch only what you must. Don't improve adjacent code or refactor unrelated things. Match existing style. When your changes create orphans (unused imports/vars/functions), remove them — but don't remove pre-existing dead code unless asked.

### 4. Goal-Driven Execution
Transform tasks into verifiable goals. For multi-step tasks, state a brief plan with verify steps. Loop until verified.
