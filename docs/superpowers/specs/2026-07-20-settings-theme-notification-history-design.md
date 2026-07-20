# 설정 영구저장 + 테마 선택 + 알림 기록 (2026-07-20)

## 배경

세 가지 요청:
1. 앱 업데이트(새 APK 덮어쓰기 설치) 후 설정 화면의 아침 브리핑 등 토글이 초기화되는 버그
2. 테마(라이트/다크 + 색상) 선택 기능
3. 파트너가 일정을 등록/수정/제안했을 때 오는 푸시 알림을, 놓쳐도 앱 안에서 나중에 조회할 수 있는 기록 기능

세 항목 모두 "사용자별 설정/기록을 기기 로컬이 아니라 계정(Firestore)에 영구 저장한다"는 같은 축으로 묶여 있어 한 스펙으로 다룬다.

## 1. 설정 영구저장 (버그 수정 겸 기반 작업)

### 현재 구조의 문제
`HolidayPrefs`, `BriefingPrefs`는 `SharedPreferences`(기기 로컬)에만 저장한다. 사용자가 실제로 겪은 증상: 앱 업데이트(새 APK 덮어쓰기 설치) 직후 설정 화면의 아침 브리핑 스위치 등이 초기화되어 있음. 평소 설정 화면을 들어갈 때는 재현되지 않음 — 업데이트 시점에만 발생. 정확한 OS 레벨 원인(서명 이력, 백업 정책 등)은 기기 로그 없이 확정하기 어렵다. 근본 원인을 특정하는 대신, 계정 기반 저장으로 옮겨 로컬 스토리지가 어떤 이유로 날아가도 영향받지 않게 만든다.

### 변경
- `UserModel`에 필드 추가: `showKoreanHolidays: bool` (기본 true), `briefingEnabled: bool` (기본 false), `briefingHour: int` (기본 8), `briefingMinute: int` (기본 0), `themeMode: String` (`'system' | 'light' | 'dark'`, 기본 `'system'`), `themeSeedColor: int?` (기본 null → 앱 기본 시드컬러 사용)
- `FirestoreService`에 `Future<void> updateUserSettings(String uid, Map<String, dynamic> fields)` 추가 — `users/{uid}` 문서에 `set(..., SetOptions(merge: true))`
- 기존 `holidayDisplayEnabledProvider`(FutureProvider)를 제거하고, 설정 화면은 `currentUserModelProvider`(기존 실시간 스트림)에서 값을 읽어 사용 — 실시간 반영되고 별도 invalidate 불필요
- 마이그레이션: 앱 시작 시 1회, `UserModel`의 새 필드가 Firestore 원본 문서에 아직 없으면(구버전 문서) 기존 `HolidayPrefs.loadEnabled()` / `BriefingPrefs.load()` 값을 읽어 `updateUserSettings`로 승격 저장. 이후 `holiday_prefs.dart`, `briefing_prefs.dart` 파일과 그 사용처를 삭제한다.
- `_HolidaySection`, `_BriefingSection`은 `ConsumerWidget`으로 단순화 가능(로컬 `initState` 로딩 불필요, provider 값 바로 사용). 변경 시 `onChanged`/`_apply`는 `updateUserSettings` 호출로 교체.

### 검증
- 기존 `flutter test` 스위트 통과
- 마이그레이션 로직 단위 테스트: 구버전 문서(새 필드 없음) → SharedPreferences 값이 Firestore로 승격되는지
- 실기기: 설정 값 변경 → 앱 재설치(덮어쓰기) → 값 유지 확인

## 2. 테마 선택

### 구성
- `themeMode`: 시스템 / 라이트 / 다크 3단 세그먼트 버튼 (`SegmentedButton<ThemeMode>` 또는 3버튼 `ToggleButtons`)
- `themeSeedColor`: 파트너 색상 선택(`_pickMyColor`)과 동일한 그리드 다이얼로그 패턴 재사용, `kCouplePalette` 색상 중 선택, ARGB int로 저장. `null`이면 기존 `kPrimaryPurple` 사용
- 설정 화면에 "테마" 섹션 신설 (기념일 관리 아래, 공휴일 섹션 위 정도)
- `CoyHouseCalenderApp`(`main.dart`)이 `currentUserModelProvider`를 watch해서 `theme`(라이트), `darkTheme`(다크), `themeMode`를 `MaterialApp.router`에 전달. 다크 테마는 `ColorScheme.fromSeed(seedColor: ..., brightness: Brightness.dark)`로 라이트와 동일한 시드 기반 생성 — 별도 다크 전용 색상 하드코딩 없음.
- 로그인 전(설정 화면 진입 불가 상태)에는 시드컬러 기본값 + 시스템 모드로 폴백

### 검증
- 수동: 라이트/다크/시스템 전환, 시드컬러 변경 시 앱 전체 반영 확인 (실기기, 다크모드는 OS 다크모드 토글로 시스템 옵션 확인)

## 3. 파트너 알림 기록

### 배경
`functions/index.js`의 `sendToPartner`가 파트너의 이벤트 생성/수정/제안/수락 시 FCM 푸시를 보낸다. 현재 `data` 페이로드에 `type: "event_sync"`만 있고 `eventId`가 없어, 클라이언트가 알림을 받아도 "무슨 일정인지" 연결할 방법이 없다. 알림을 놓치면(스와이프로 지움 등) 다시 확인할 방법이 없다.

### 변경
- **Cloud Function** (`functions/index.js`): `sendToPartner` 호출 시 이벤트 id를 함께 전달하도록 시그니처 변경(`sendToPartner(event, eventId, actorUid, notificationTitle)`), `data` 페이로드에 `eventId: eventId ?? ""` 추가. `notification.title`/`body`도 그대로 `data`에 중복 포함(`data.title`, `data.body`) — 클라이언트가 기록 저장 시 `RemoteMessage.notification`이 없는 데이터 전용 메시지 상황(백그라운드 kill 상태 등)에서도 안전하게 값을 얻기 위함
- **클라이언트 — 알림 도착 시 기록**:
  - `main.dart`의 `_firebaseMessagingBackgroundHandler`: `type == 'event_sync'`일 때 기존 동기화 로직 실행 전/후에 Firestore `users/{uid}/notificationHistory` 서브컬렉션에 문서 추가 (`title, body, eventId, receivedAt: FieldValue.serverTimestamp()`)
  - `main.dart`의 `FirebaseMessaging.onMessage`(포그라운드): 동일하게 기록 추가 (현재는 아무 것도 안 함 → 여기에 기록 로직 추가)
  - 공통 헬퍼로 추출: `Future<void> _recordNotificationHistory(RemoteMessage message)` — 최신 50개 초과 시 가장 오래된 문서부터 삭제(쓰기 직후 `orderBy('receivedAt', descending: true).offset(50)` 조회 후 삭제, 실패해도 무시)
- **알림 기록 화면** (신규 `lib/screens/settings/notification_history_screen.dart`):
  - `users/{uid}/notificationHistory` 를 `receivedAt desc`로 스트림 구독, `ListTile`로 제목/본문/수신시각 표시
  - 탭 시: `eventsStreamProvider`에서 `eventId`로 이벤트 검색 → 있으면 `/event/detail`로 이동(`extra: event`), 없으면 스낵바 "삭제된 일정입니다"
  - 설정 화면에 "알림 기록" 메뉴 추가 (기념일 관리 근처)

### 검증
- 함수 배포 후 실기기 2대(본인/파트너)로 일정 생성 → 상대 기기에 푸시 도착 + 기록 화면에 항목 생김 확인
- 앱이 완전 종료된 상태(백그라운드 핸들러 경로)에서도 기록되는지 확인
- 기존 `flutter test` 통과 (Cloud Function은 Node 쪽이라 별도 스위트 없음 — 수동 검증)

## 범위 밖
- 알림 기록 읽음/안읽음 배지, 알림 기록 삭제 UI는 포함하지 않음 (요청에 없었음)
- 테마는 시드컬러 프리셋 선택만 지원, 커스텀 컬러피커(RGB 슬라이더 등)는 없음
- 설정 영구저장 대상은 이번에 다루는 3개 필드군(공휴일/브리핑/테마)만 — 다른 로컬 상태(캘린더 매핑 등)는 이번 스코프 아님
