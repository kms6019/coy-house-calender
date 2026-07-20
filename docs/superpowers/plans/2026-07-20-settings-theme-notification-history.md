# 설정 영구저장 + 테마 선택 + 알림 기록 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 설정(공휴일표시/아침브리핑/테마)을 기기 로컬(SharedPreferences)이 아닌 Firestore `users/{uid}` 문서에 저장해 앱 업데이트/재설치에도 유지되게 하고, 라이트/다크+시드컬러 테마 선택 기능을 추가하고, 파트너의 일정 알림 푸시를 앱 안에서 나중에 조회할 수 있는 기록 기능을 추가한다.

**Architecture:** `UserModel`에 설정 필드를 추가하고 `FirestoreService.updateUserSettings`로 merge 저장한다. 기존 로컬 전용 `HolidayPrefs`/`BriefingPrefs`는 1회 마이그레이션 후 삭제한다. 테마는 `currentUserModelProvider`가 흘려주는 값으로 `MaterialApp.router`를 감싼다. 알림 기록은 Cloud Function이 `eventId`를 포함한 데이터 페이로드를 보내고, 클라이언트가 FCM 수신 시점(포그라운드/백그라운드 양쪽)에 Firestore 서브컬렉션에 기록한다.

**Tech Stack:** Flutter, Riverpod, Cloud Firestore, Firebase Cloud Messaging, Firebase Cloud Functions (Node.js v2), flutter_test.

## Global Constraints

- 기존 테스트(`flutter test`, 116개+)는 계속 100% 통과해야 한다.
- Firestore/FCM에 실제로 접근하는 코드는 유닛테스트 대상에서 제외한다(프로젝트 기존 관행 — `FirestoreService`, `SamsungCalendarSyncService` 등은 순수 로직만 테스트됨). 새로 추가하는 마이그레이션/기록 로직은 Firestore 호출부와 순수 변환 로직을 분리해, 순수 로직만 유닛테스트한다.
- `set(..., SetOptions(merge: true))` 패턴 유지 (CLAUDE.md 명시 규칙) — `update()` 사용 금지.
- 커밋은 태스크 단위로 자주.

---

## 파일 구조

- `lib/models/user_model.dart` — 설정 필드 추가 (수정)
- `lib/services/firestore_service.dart` — `updateUserSettings` 추가 (수정)
- `lib/services/settings_migration.dart` — 마이그레이션 순수 로직 + 실행 함수 (신규)
- `lib/services/holiday_prefs.dart`, `lib/services/briefing_prefs.dart` — 삭제 (Task 3)
- `lib/providers/calendar_provider.dart` — `holidayDisplayEnabledProvider` 제거, `koreanHolidaysProvider`/`alarmSyncProvider`가 `currentUserModelProvider` 사용하도록 수정, `settingsMigrationProvider` 추가 (수정)
- `lib/screens/settings/settings_screen.dart` — 홀리데이/브리핑 섹션이 `UserModel` 기반으로 동작, 테마 섹션 추가, 알림기록 메뉴 추가 (수정)
- `lib/theme/app_theme.dart` — 테마 모드 문자열↔`ThemeMode` 변환 순수 함수, 다크 테마 빌더 추가 (수정)
- `lib/main.dart` — `MaterialApp.router`에 테마 와이어링, FCM 핸들러에 알림기록 저장 로직 (수정)
- `lib/services/notification_history_service.dart` — 알림기록 Firestore 읽기/쓰기 + 순수 변환 로직 (신규)
- `lib/screens/settings/notification_history_screen.dart` — 알림기록 리스트 화면 (신규)
- `lib/router/app_router.dart` — `/settings/notifications` 라우트 추가 (수정)
- `functions/index.js` — `eventId`를 데이터 페이로드에 포함 (수정)
- `test/models/user_model_test.dart` (신규), `test/services/settings_migration_test.dart` (신규), `test/theme/app_theme_test.dart` (신규), `test/services/notification_history_service_test.dart` (신규)

---

### Task 1: UserModel에 설정 필드 추가

**Files:**
- Modify: `lib/models/user_model.dart`
- Test: `test/models/user_model_test.dart` (신규)

**Interfaces:**
- Produces: `UserModel` 생성자에 `bool showKoreanHolidays`(기본 `true`), `bool briefingEnabled`(기본 `false`), `int briefingHour`(기본 `8`), `int briefingMinute`(기본 `0`), `String themeMode`(기본 `'system'`), `int? themeSeedColor`(기본 `null`) 필드 추가. `fromMap`/`toMap`/`copyWith`에 반영.

- [ ] **Step 1: 실패하는 테스트 작성**

`test/models/user_model_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coy_house_calender/models/user_model.dart';

void main() {
  test('fromMap defaults new settings fields when missing', () {
    final user = UserModel.fromMap({
      'uid': 'u1',
      'email': 'a@b.com',
      'displayName': '철수',
      'coupleId': 'c1',
      'fcmToken': 'token',
      'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
    });
    expect(user.showKoreanHolidays, true);
    expect(user.briefingEnabled, false);
    expect(user.briefingHour, 8);
    expect(user.briefingMinute, 0);
    expect(user.themeMode, 'system');
    expect(user.themeSeedColor, isNull);
  });

  test('toMap/fromMap round trip preserves settings fields', () {
    final user = UserModel(
      uid: 'u1',
      email: 'a@b.com',
      displayName: '철수',
      coupleId: 'c1',
      fcmToken: 'token',
      createdAt: DateTime(2026, 1, 1),
      showKoreanHolidays: false,
      briefingEnabled: true,
      briefingHour: 7,
      briefingMinute: 30,
      themeMode: 'dark',
      themeSeedColor: 0xFF7E57C2,
    );
    final restored = UserModel.fromMap(user.toMap());
    expect(restored.showKoreanHolidays, false);
    expect(restored.briefingEnabled, true);
    expect(restored.briefingHour, 7);
    expect(restored.briefingMinute, 30);
    expect(restored.themeMode, 'dark');
    expect(restored.themeSeedColor, 0xFF7E57C2);
  });

  test('copyWith overrides settings fields independently', () {
    const user = UserModel(
      uid: 'u1',
      email: 'a@b.com',
      displayName: '철수',
      coupleId: 'c1',
      fcmToken: 'token',
      createdAt: null,
    );
  });
}
```

주의: 마지막 `copyWith` 테스트 블록은 `createdAt: null`이 컴파일 안 되므로 그대로 두면 안 된다 — 아래처럼 정정해서 작성한다:
```dart
  test('copyWith overrides settings fields independently', () {
    final user = UserModel(
      uid: 'u1',
      email: 'a@b.com',
      displayName: '철수',
      coupleId: 'c1',
      fcmToken: 'token',
      createdAt: DateTime(2026, 1, 1),
    );
    final updated = user.copyWith(themeMode: 'light', briefingHour: 9);
    expect(updated.themeMode, 'light');
    expect(updated.briefingHour, 9);
    expect(updated.showKoreanHolidays, true); // 나머진 기존값 유지
  });
```

- [ ] **Step 2: 테스트 실행해서 실패 확인**

Run: `flutter test test/models/user_model_test.dart`
Expected: FAIL — `showKoreanHolidays` 등 named parameter 없음 컴파일 에러

- [ ] **Step 3: UserModel 수정**

`lib/models/user_model.dart` 전체를 아래로 교체:
```dart
import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String coupleId;
  final String fcmToken;
  final DateTime createdAt;
  final bool showKoreanHolidays;
  final bool briefingEnabled;
  final int briefingHour;
  final int briefingMinute;
  final String themeMode;
  final int? themeSeedColor;

  const UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.coupleId,
    required this.fcmToken,
    required this.createdAt,
    this.showKoreanHolidays = true,
    this.briefingEnabled = false,
    this.briefingHour = 8,
    this.briefingMinute = 0,
    this.themeMode = 'system',
    this.themeSeedColor,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] as String? ?? '',
      email: map['email'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      coupleId: map['coupleId'] as String? ?? '',
      fcmToken: map['fcmToken'] as String? ?? '',
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      showKoreanHolidays: map['showKoreanHolidays'] as bool? ?? true,
      briefingEnabled: map['briefingEnabled'] as bool? ?? false,
      briefingHour: map['briefingHour'] as int? ?? 8,
      briefingMinute: map['briefingMinute'] as int? ?? 0,
      themeMode: map['themeMode'] as String? ?? 'system',
      themeSeedColor: map['themeSeedColor'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'coupleId': coupleId,
      'fcmToken': fcmToken,
      'createdAt': Timestamp.fromDate(createdAt),
      'showKoreanHolidays': showKoreanHolidays,
      'briefingEnabled': briefingEnabled,
      'briefingHour': briefingHour,
      'briefingMinute': briefingMinute,
      'themeMode': themeMode,
      'themeSeedColor': themeSeedColor,
    };
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? coupleId,
    String? fcmToken,
    DateTime? createdAt,
    bool? showKoreanHolidays,
    bool? briefingEnabled,
    int? briefingHour,
    int? briefingMinute,
    String? themeMode,
    int? themeSeedColor,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      coupleId: coupleId ?? this.coupleId,
      fcmToken: fcmToken ?? this.fcmToken,
      createdAt: createdAt ?? this.createdAt,
      showKoreanHolidays: showKoreanHolidays ?? this.showKoreanHolidays,
      briefingEnabled: briefingEnabled ?? this.briefingEnabled,
      briefingHour: briefingHour ?? this.briefingHour,
      briefingMinute: briefingMinute ?? this.briefingMinute,
      themeMode: themeMode ?? this.themeMode,
      themeSeedColor: themeSeedColor ?? this.themeSeedColor,
    );
  }
}
```

- [ ] **Step 4: 테스트 실행해서 통과 확인**

Run: `flutter test test/models/user_model_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: 커밋**

```bash
git add lib/models/user_model.dart test/models/user_model_test.dart
git commit -m "feat: UserModel에 설정 필드(공휴일/브리핑/테마) 추가"
```

---

### Task 2: FirestoreService.updateUserSettings + 마이그레이션 순수 로직

**Files:**
- Modify: `lib/services/firestore_service.dart`
- Create: `lib/services/settings_migration.dart`
- Test: `test/services/settings_migration_test.dart` (신규)

**Interfaces:**
- Consumes: `UserModel` (Task 1)
- Produces: `FirestoreService.updateUserSettings(String uid, Map<String, dynamic> fields) -> Future<void>`. `SettingsMigrationService.fieldsToWrite(Map<String, dynamic> rawUserDoc, {required bool legacyHolidayEnabled, required bool legacyBriefingEnabled, required int legacyBriefingHour, required int legacyBriefingMinute}) -> Map<String, dynamic>?` (순수 함수, static). `SettingsMigrationService().runIfNeeded(String uid) -> Future<void>` (Firestore/SharedPreferences 접근, 테스트 대상 아님).

- [ ] **Step 1: 실패하는 테스트 작성**

`test/services/settings_migration_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:coy_house_calender/services/settings_migration.dart';

void main() {
  test('returns migration fields when themeMode key missing', () {
    final fields = SettingsMigrationService.fieldsToWrite(
      {'uid': 'u1', 'coupleId': 'c1'},
      legacyHolidayEnabled: false,
      legacyBriefingEnabled: true,
      legacyBriefingHour: 7,
      legacyBriefingMinute: 15,
    );
    expect(fields, isNotNull);
    expect(fields!['showKoreanHolidays'], false);
    expect(fields['briefingEnabled'], true);
    expect(fields['briefingHour'], 7);
    expect(fields['briefingMinute'], 15);
    expect(fields['themeMode'], 'system');
    expect(fields['themeSeedColor'], isNull);
  });

  test('returns null when themeMode key already present (already migrated)', () {
    final fields = SettingsMigrationService.fieldsToWrite(
      {'uid': 'u1', 'themeMode': 'dark'},
      legacyHolidayEnabled: false,
      legacyBriefingEnabled: false,
      legacyBriefingHour: 8,
      legacyBriefingMinute: 0,
    );
    expect(fields, isNull);
  });
}
```

- [ ] **Step 2: 테스트 실행해서 실패 확인**

Run: `flutter test test/services/settings_migration_test.dart`
Expected: FAIL — `settings_migration.dart` 파일 없음

- [ ] **Step 3: 구현**

`lib/services/firestore_service.dart`에 메서드 추가 (클래스 내 `updateMyColor` 아래, `// ── Events ──` 위):
```dart
  Future<void> updateUserSettings(String uid, Map<String, dynamic> fields) {
    return _db.collection('users').doc(uid).set(fields, SetOptions(merge: true));
  }
```

`lib/services/settings_migration.dart` (신규):
```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'holiday_prefs.dart';
import 'briefing_prefs.dart';

/// 구버전(SharedPreferences 전용) 설정을 Firestore users/{uid} 문서로
/// 1회 승격시킨다. themeMode 필드가 이미 있으면 승격 완료로 간주하고 스킵한다.
class SettingsMigrationService {
  final FirebaseFirestore _db;
  SettingsMigrationService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  static Map<String, dynamic>? fieldsToWrite(
    Map<String, dynamic> rawUserDoc, {
    required bool legacyHolidayEnabled,
    required bool legacyBriefingEnabled,
    required int legacyBriefingHour,
    required int legacyBriefingMinute,
  }) {
    if (rawUserDoc.containsKey('themeMode')) return null;
    return {
      'showKoreanHolidays': legacyHolidayEnabled,
      'briefingEnabled': legacyBriefingEnabled,
      'briefingHour': legacyBriefingHour,
      'briefingMinute': legacyBriefingMinute,
      'themeMode': 'system',
      'themeSeedColor': null,
    };
  }

  Future<void> runIfNeeded(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return;
    final briefing = await BriefingPrefs.load();
    final fields = fieldsToWrite(
      doc.data()!,
      legacyHolidayEnabled: await HolidayPrefs.loadEnabled(),
      legacyBriefingEnabled: briefing.enabled,
      legacyBriefingHour: briefing.hour,
      legacyBriefingMinute: briefing.minute,
    );
    if (fields == null) return;
    await _db.collection('users').doc(uid).set(fields, SetOptions(merge: true));
  }
}
```

- [ ] **Step 4: 테스트 실행해서 통과 확인**

Run: `flutter test test/services/settings_migration_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 5: 커밋**

```bash
git add lib/services/firestore_service.dart lib/services/settings_migration.dart test/services/settings_migration_test.dart
git commit -m "feat: 설정 Firestore 승격용 updateUserSettings + 마이그레이션 로직"
```

---

### Task 3: 마이그레이션 실행 연결 + 홀리데이/브리핑을 UserModel 기반으로 전환 + 구 prefs 삭제

**Files:**
- Modify: `lib/providers/calendar_provider.dart`
- Modify: `lib/screens/settings/settings_screen.dart`
- Delete: `lib/services/holiday_prefs.dart`, `lib/services/briefing_prefs.dart`
- Delete: `test/services/holiday_prefs_test.dart` (있다면), `test/services/briefing_prefs_test.dart` (있다면) — 없으면 스킵
- Test: 기존 `flutter test` 전체로 회귀 확인 (신규 테스트 없음 — provider/위젯 배선 변경이라 기존 스위트로 커버)

**Interfaces:**
- Consumes: `UserModel.showKoreanHolidays/briefingEnabled/briefingHour/briefingMinute` (Task 1), `FirestoreService.updateUserSettings` (Task 2), `SettingsMigrationService` (Task 2)
- Produces: `koreanHolidaysProvider`가 `currentUserModelProvider` 기반으로 동작. `settingsMigrationProvider`(Provider<void>, `calendar_provider.dart`에 추가)가 uid 등장 시 1회 `runIfNeeded` 호출.

- [ ] **Step 1: 삭제 대상 확인**

Run: `ls test/services/holiday_prefs_test.dart test/services/briefing_prefs_test.dart 2>&1`

존재하는 파일만 다음 스텝에서 `git rm`.

- [ ] **Step 2: calendar_provider.dart 수정**

`holidayDisplayEnabledProvider`, `koreanHolidaysProvider`를 아래로 교체 (기존 라인 24-35):
```dart
final koreanHolidaysProvider = FutureProvider.family<List<KoreanHoliday>, int>((
  ref,
  year,
) async {
  final enabled =
      ref.watch(currentUserModelProvider).valueOrNull?.showKoreanHolidays ?? true;
  if (!enabled) return const <KoreanHoliday>[];
  return ref.watch(koreanHolidayServiceProvider).getHolidaysForYear(year);
});
```

`alarmSyncProvider`(브리핑 부분)를 `BriefingPrefs.load()` 대신 `UserModel`을 쓰도록 교체:
```dart
final alarmSyncProvider = Provider<void>((ref) {
  final events = ref.watch(eventsStreamProvider).valueOrNull;
  if (events == null) return;
  final ns = NotificationService();
  for (final event in events) {
    ns.cancelAlarm(event.id).then((_) {
      if (event.hasAlarm) ns.scheduleAlarm(event);
    });
  }

  final user = ref.watch(currentUserModelProvider).valueOrNull;
  ns.scheduleBriefings(
    events: events,
    enabled: user?.briefingEnabled ?? false,
    hour: user?.briefingHour ?? 8,
    minute: user?.briefingMinute ?? 0,
  );
});
```

파일 끝(`focusedDateProvider` 아래)에 마이그레이션 트리거 provider 추가:
```dart
// 구버전 SharedPreferences 설정을 Firestore로 1회 승격
final settingsMigrationProvider = Provider<void>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return;
  SettingsMigrationService().runIfNeeded(uid);
});
```

import 추가: `import 'auth_provider.dart';`(이미 있음), `import '../services/settings_migration.dart';`. `BriefingPrefs`/`HolidayPrefs` import 제거.

`lib/screens/calendar/calendar_screen.dart`의 `build` 메서드 상단, 기존 `ref.watch(widgetSyncProvider);` 옆에 한 줄 추가:
```dart
    ref.watch(settingsMigrationProvider);
```

- [ ] **Step 3: settings_screen.dart의 `_HolidaySection`/`_BriefingSection` 교체**

기존 `_HolidaySection`(전체)을 아래로 교체:
```dart
class _HolidaySection extends ConsumerWidget {
  const _HolidaySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserModelProvider);
    return userAsync.when(
      data: (user) => SwitchListTile(
        secondary: const Icon(Icons.flag_outlined),
        title: const Text('대한민국 공휴일 표시'),
        subtitle: const Text('법정·대체·임시공휴일과 선거일을 달력에 표시'),
        value: user?.showKoreanHolidays ?? true,
        onChanged: (value) async {
          final uid = ref.read(authStateProvider).valueOrNull?.uid;
          if (uid == null) return;
          await ref
              .read(firestoreServiceProvider)
              .updateUserSettings(uid, {'showKoreanHolidays': value});

          final events = ref.read(eventsStreamProvider).valueOrNull ?? [];
          final anniversaries =
              ref.read(coupleStreamProvider).valueOrNull?.anniversaries ??
              const [];
          await WidgetService.update(events, anniversaries: anniversaries);
        },
      ),
      loading: () => const ListTile(
        leading: Icon(Icons.flag_outlined),
        title: Text('대한민국 공휴일 표시'),
        trailing: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
```

기존 `_BriefingSection`/`_BriefingSectionState`(전체)를 아래로 교체 (더 이상 `initState` 로딩 불필요 — `ConsumerWidget`으로 단순화):
```dart
class _BriefingSection extends ConsumerWidget {
  const _BriefingSection();

  Future<void> _apply(
    WidgetRef ref, {
    required bool enabled,
    required int hour,
    required int minute,
  }) async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    await ref.read(firestoreServiceProvider).updateUserSettings(uid, {
      'briefingEnabled': enabled,
      'briefingHour': hour,
      'briefingMinute': minute,
    });
    final events = ref.read(eventsStreamProvider).valueOrNull ?? [];
    await NotificationService().scheduleBriefings(
      events: events,
      enabled: enabled,
      hour: hour,
      minute: minute,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserModelProvider).valueOrNull;
    if (user == null) return const SizedBox.shrink();
    return Column(
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.wb_sunny_outlined),
          title: const Text('아침 브리핑'),
          subtitle: const Text('매일 아침 오늘 일정 요약 알림 (일정 없는 날 제외)'),
          value: user.briefingEnabled,
          onChanged: (v) => _apply(
            ref,
            enabled: v,
            hour: user.briefingHour,
            minute: user.briefingMinute,
          ),
        ),
        if (user.briefingEnabled)
          ListTile(
            contentPadding: const EdgeInsets.only(left: 72, right: 16),
            title: const Text('브리핑 시간'),
            trailing: Text(
              '${user.briefingHour.toString().padLeft(2, '0')}:${user.briefingMinute.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 16),
            ),
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime:
                    TimeOfDay(hour: user.briefingHour, minute: user.briefingMinute),
              );
              if (picked != null) {
                _apply(
                  ref,
                  enabled: true,
                  hour: picked.hour,
                  minute: picked.minute,
                );
              }
            },
          ),
      ],
    );
  }
}
```

`settings_screen.dart` 상단 import에 `import '../../providers/calendar_provider.dart';`(이미 `currentUserModelProvider`/`firestoreServiceProvider`/`eventsStreamProvider`/`coupleStreamProvider` 제공 — `auth_provider.dart`는 이미 import되어 있는지 확인, 없으면 추가) 필요 여부 확인 후 추가. 기존 `import '../../services/briefing_prefs.dart';`, `import '../../services/holiday_prefs.dart';` 줄 삭제.

- [ ] **Step 4: 구 prefs 파일 삭제**

```bash
git rm lib/services/holiday_prefs.dart lib/services/briefing_prefs.dart
```
(Task 2의 `settings_migration.dart`가 이 두 파일을 import하므로, 이 스텝은 Task 2에서 마이그레이션이 필요 없어진 뒤 — 즉 전체 마이그레이션 기간이 끝나고 별도로 처리할 대상이다. **지금 삭제하면 `settings_migration.dart`가 깨진다.** 따라서 이 스텝은 스킵하고 아래 "주의"를 따른다.)

**주의:** `holiday_prefs.dart`/`briefing_prefs.dart`는 `settings_migration.dart`의 `runIfNeeded()`가 레거시 값을 읽기 위해 계속 참조한다. 앱 배포 후 모든 사용자의 문서가 마이그레이션되었다고 확신할 수 있을 때(예: 다음 대규모 정리 시점)까지 두 파일은 **삭제하지 않는다**. 스펙의 "삭제" 항목은 이 마이그레이션 참조 관계를 반영해 유예한다 — `settings_screen.dart`의 직접 import만 제거하고 파일 자체는 유지한다.

- [ ] **Step 5: 전체 테스트 실행**

Run: `flutter test`
Expected: PASS, 전체 그린 (기존 116+ 전부 + Task 1/2 신규)

- [ ] **Step 6: 커밋**

```bash
git add lib/providers/calendar_provider.dart lib/screens/settings/settings_screen.dart lib/screens/calendar/calendar_screen.dart
git commit -m "feat: 공휴일/브리핑 설정을 Firestore 기반으로 전환, 마이그레이션 연결"
```

---

### Task 4: 테마 모드/시드컬러 → MaterialApp 와이어링

**Files:**
- Modify: `lib/theme/app_theme.dart`
- Modify: `lib/main.dart`
- Test: `test/theme/app_theme_test.dart` (신규)

**Interfaces:**
- Consumes: `UserModel.themeMode`, `UserModel.themeSeedColor` (Task 1)
- Produces: `resolveThemeMode(String value) -> ThemeMode` (순수 함수). `buildLightTheme(int seedColor) -> ThemeData`, `buildDarkTheme(int seedColor) -> ThemeData` (순수, Flutter 위젯 트리 불필요라 유닛테스트 가능 — `ThemeData` 객체 속성만 검사).

- [ ] **Step 1: 실패하는 테스트 작성**

`test/theme/app_theme_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coy_house_calender/theme/app_theme.dart';

void main() {
  test('resolveThemeMode maps known strings', () {
    expect(resolveThemeMode('light'), ThemeMode.light);
    expect(resolveThemeMode('dark'), ThemeMode.dark);
    expect(resolveThemeMode('system'), ThemeMode.system);
  });

  test('resolveThemeMode falls back to system for unknown value', () {
    expect(resolveThemeMode('weird'), ThemeMode.system);
  });

  test('buildLightTheme uses given seed color with light brightness', () {
    final theme = buildLightTheme(0xFF7E57C2);
    expect(theme.brightness, Brightness.light);
    expect(theme.useMaterial3, true);
  });

  test('buildDarkTheme uses given seed color with dark brightness', () {
    final theme = buildDarkTheme(0xFF7E57C2);
    expect(theme.brightness, Brightness.dark);
    expect(theme.useMaterial3, true);
  });
}
```

- [ ] **Step 2: 테스트 실행해서 실패 확인**

Run: `flutter test test/theme/app_theme_test.dart`
Expected: FAIL — `resolveThemeMode`/`buildLightTheme`/`buildDarkTheme` 없음

- [ ] **Step 3: app_theme.dart 구현**

`lib/theme/app_theme.dart` 전체를 아래로 교체:
```dart
import 'package:flutter/material.dart';

const kPrimaryPurple = Color(0xFF7E57C2);

ThemeMode resolveThemeMode(String value) {
  switch (value) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    default:
      return ThemeMode.system;
  }
}

ThemeData buildLightTheme(int seedColor) {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Color(seedColor),
      brightness: Brightness.light,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Color(seedColor),
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    useMaterial3: true,
  );
}

ThemeData buildDarkTheme(int seedColor) {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Color(seedColor),
      brightness: Brightness.dark,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Color(seedColor),
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    useMaterial3: true,
  );
}
```

- [ ] **Step 4: 테스트 실행해서 통과 확인**

Run: `flutter test test/theme/app_theme_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 5: main.dart의 MaterialApp 와이어링**

`lib/main.dart`의 `CoyHouseCalenderApp` 클래스를 아래로 교체:
```dart
class CoyHouseCalenderApp extends ConsumerWidget {
  const CoyHouseCalenderApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final user = ref.watch(currentUserModelProvider).valueOrNull;
    final seedColor = user?.themeSeedColor ?? kPrimaryPurple.toARGB32();
    return MaterialApp.router(
      title: 'CoyHouse Calendar',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(seedColor),
      darkTheme: buildDarkTheme(seedColor),
      themeMode: resolveThemeMode(user?.themeMode ?? 'system'),
      routerConfig: router,
    );
  }
}
```

`import 'providers/calendar_provider.dart' show currentUserModelProvider;`가 없으면 추가 (또는 프로젝트 관례상 `currentUserModelProvider`가 `auth_provider.dart`에 정의되어 있다면 그쪽을 import — Task 3에서 확인한 실제 위치를 따른다).

- [ ] **Step 6: 전체 테스트 실행**

Run: `flutter test`
Expected: PASS 전체

- [ ] **Step 7: 커밋**

```bash
git add lib/theme/app_theme.dart lib/main.dart test/theme/app_theme_test.dart
git commit -m "feat: 라이트/다크 테마 + 시드컬러 MaterialApp 와이어링"
```

---

### Task 5: 설정 화면 "테마" 섹션 UI

**Files:**
- Modify: `lib/screens/settings/settings_screen.dart`

**Interfaces:**
- Consumes: `resolveThemeMode`, `kCouplePalette`(기존, `theme/couple_palette.dart`), `FirestoreService.updateUserSettings` (Task 2), `UserModel.themeMode/themeSeedColor` (Task 1)

- [ ] **Step 1: `_ThemeSection` 위젯 추가**

`settings_screen.dart`에 `_HolidaySection` 클래스 앞에 추가:
```dart
class _ThemeSection extends ConsumerWidget {
  const _ThemeSection();

  Future<void> _pickColor(BuildContext context, WidgetRef ref, int? current) async {
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('테마 색상'),
        content: SizedBox(
          width: 280,
          child: GridView.count(
            shrinkWrap: true,
            crossAxisCount: 4,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: kCouplePalette.map((c) {
              final isMine = c == current;
              return InkWell(
                onTap: () => Navigator.pop(ctx, c),
                customBorder: const CircleBorder(),
                child: Container(
                  decoration: BoxDecoration(color: Color(c), shape: BoxShape.circle),
                  child: isMine
                      ? Icon(
                          Icons.check,
                          color: Color(c).computeLuminance() > 0.5
                              ? Colors.black54
                              : Colors.white,
                        )
                      : null,
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
        ],
      ),
    );
    if (picked == null) return;
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    await ref
        .read(firestoreServiceProvider)
        .updateUserSettings(uid, {'themeSeedColor': picked});
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserModelProvider).valueOrNull;
    final mode = user?.themeMode ?? 'system';
    final seedColor = user?.themeSeedColor ?? kPrimaryPurple.toARGB32();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: const Icon(Icons.palette_outlined),
          title: const Text('테마'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'system', label: Text('시스템')),
              ButtonSegment(value: 'light', label: Text('라이트')),
              ButtonSegment(value: 'dark', label: Text('다크')),
            ],
            selected: {mode},
            onSelectionChanged: (selection) async {
              final uid = ref.read(authStateProvider).valueOrNull?.uid;
              if (uid == null) return;
              await ref
                  .read(firestoreServiceProvider)
                  .updateUserSettings(uid, {'themeMode': selection.first});
            },
          ),
        ),
        ListTile(
          contentPadding: const EdgeInsets.only(left: 16, right: 16, top: 8),
          title: const Text('색상'),
          trailing: GestureDetector(
            onTap: () => _pickColor(context, ref, user?.themeSeedColor),
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(color: Color(seedColor), shape: BoxShape.circle),
            ),
          ),
        ),
      ],
    );
  }
}
```

`settings_screen.dart` 상단에 `import '../../theme/couple_palette.dart';`(이미 있음), `import '../../theme/app_theme.dart' show kPrimaryPurple;` 추가.

`build` 메서드의 위젯 목록에서 "기념일 관리" `Divider` 다음에 삽입:
```dart
          const _ThemeSection(),
          const Divider(),
```

- [ ] **Step 2: 정적 분석**

Run: `flutter analyze`
Expected: 새 경고/에러 없음

- [ ] **Step 3: 전체 테스트 실행**

Run: `flutter test`
Expected: PASS 전체

- [ ] **Step 4: 실기기 수동 확인**

`flutter run -d R3CW70R1BCW` (또는 WiFi 디버깅 기기) → 설정 → 테마에서 라이트/다크/시스템 전환, 색상 변경 후 앱 전체(AppBar, 버튼 등) 색 반영되는지 확인.

- [ ] **Step 5: 커밋**

```bash
git add lib/screens/settings/settings_screen.dart
git commit -m "feat: 설정 화면에 테마 선택 섹션 추가"
```

---

### Task 6: Cloud Function — eventId를 알림 데이터 페이로드에 포함

**Files:**
- Modify: `functions/index.js`

**Interfaces:**
- Produces: FCM 메시지 `data`에 `eventId`, `title`, `body` 포함 (기존엔 `type`만 있었음).

- [ ] **Step 1: `sendToPartner` 시그니처 변경**

`functions/index.js`의 `sendToPartner` 함수를 아래로 교체:
```javascript
async function sendToPartner(event, eventId, actorUid, notificationTitle) {
  const db = admin.firestore();

  const coupleId = event.coupleId ?? "";
  if (!coupleId || !actorUid) return;

  const coupleSnap = await db.collection("couples").doc(coupleId).get();
  if (!coupleSnap.exists) return;
  const couple = coupleSnap.data();
  if (couple.isLinked !== true) return;

  const partnerUid =
    couple.ownerUid === actorUid ? couple.partnerUid : couple.ownerUid;
  if (!partnerUid || partnerUid === actorUid) return;

  const [partnerSnap, actorSnap] = await Promise.all([
    db.collection("users").doc(partnerUid).get(),
    db.collection("users").doc(actorUid).get(),
  ]);
  const fcmToken = partnerSnap.data()?.fcmToken ?? "";
  if (!fcmToken) return;

  const actorName = (actorSnap.data()?.displayName ?? "").trim() || "상대방";
  const title = (event.title ?? "").trim() || "(제목 없음)";
  const when = event.startDateTime
    ? formatStart(event.startDateTime, event.isAllDay === true)
    : "";

  const notifTitle = `${actorName}님이 ${notificationTitle}`;
  const notifBody = when ? `${title} · ${when}` : title;

  await admin.messaging().send({
    token: fcmToken,
    notification: {
      title: notifTitle,
      body: notifBody,
    },
    // 수신 기기가 백그라운드에서 캘린더/위젯 동기화를 돌리고, 알림 기록에 남기도록
    // 데이터 페이로드에 eventId/title/body를 함께 보낸다.
    data: {
      type: "event_sync",
      eventId: eventId ?? "",
      title: notifTitle,
      body: notifBody,
    },
    android: { priority: "high" },
  });
}
```

호출부 두 곳(`onEventCreated`, `onEventUpdated`)을 각각 `eventId` 인자를 넘기도록 수정:
```javascript
exports.onEventCreated = onDocumentCreated("events/{eventId}", async (event) => {
  const data = event.data?.data();
  if (!data) return;
  const title =
    data.status === "proposed" ? "일정을 제안했어요" : "일정을 등록했어요";
  await sendToPartner(data, event.params.eventId, data.createdByUid ?? "", title);
});

exports.onEventUpdated = onDocumentUpdated("events/{eventId}", async (event) => {
  const before = event.data?.before?.data();
  const after = event.data?.after?.data();
  if (!before || !after) return;
  const actorUid = after.lastEditorUid ?? after.createdByUid ?? "";

  // 제안 수락: proposed → confirmed 전이는 다른 필드 변경 없어도 발송
  if (before.status === "proposed" && after.status === "confirmed") {
    await sendToPartner(after, event.params.eventId, actorUid, "제안을 수락했어요");
    return;
  }

  if (!hasMeaningfulChange(before, after)) return;
  await sendToPartner(after, event.params.eventId, actorUid, "일정을 수정했어요");
});
```

- [ ] **Step 2: 배포**

Run: `cd functions && npm run lint 2>&1 | head -50` (린트 스크립트가 있으면 통과 확인, 없으면 스킵)
Run: `firebase deploy --only functions --project coy-house-calender`
Expected: `onEventCreated`, `onEventUpdated` 배포 성공 로그

- [ ] **Step 3: 커밋**

```bash
git add functions/index.js
git commit -m "feat: 파트너 알림 데이터 페이로드에 eventId 포함"
```

---

### Task 7: 클라이언트 — 알림 기록 저장 로직

**Files:**
- Create: `lib/services/notification_history_service.dart`
- Modify: `lib/main.dart`
- Test: `test/services/notification_history_service_test.dart` (신규)

**Interfaces:**
- Consumes: FCM `data` 맵 (Task 6에서 보낸 `eventId`/`title`/`body`)
- Produces: `NotificationHistoryEntry` (id, title, body, eventId, receivedAt) — `NotificationHistoryEntry.fromFcmData(Map<String, dynamic> data) -> NotificationHistoryEntry?` (순수 함수, `type != 'event_sync'`면 `null`). `NotificationHistoryService.record(String uid, NotificationHistoryEntry entry) -> Future<void>` (Firestore 쓰기 + 50개 초과분 정리, 테스트 대상 아님). `NotificationHistoryService.streamFor(String uid) -> Stream<List<NotificationHistoryEntry>>`.

- [ ] **Step 1: 실패하는 테스트 작성**

`test/services/notification_history_service_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:coy_house_calender/services/notification_history_service.dart';

void main() {
  test('fromFcmData parses event_sync payload', () {
    final entry = NotificationHistoryEntry.fromFcmData({
      'type': 'event_sync',
      'eventId': 'ev1',
      'title': '철수님이 일정을 등록했어요',
      'body': '여행 · 7월 22일 (수) 종일',
    });
    expect(entry, isNotNull);
    expect(entry!.eventId, 'ev1');
    expect(entry.title, '철수님이 일정을 등록했어요');
    expect(entry.body, '여행 · 7월 22일 (수) 종일');
  });

  test('fromFcmData returns null for non event_sync payload', () {
    final entry = NotificationHistoryEntry.fromFcmData({'type': 'other'});
    expect(entry, isNull);
  });

  test('fromFcmData returns null when eventId missing', () {
    final entry = NotificationHistoryEntry.fromFcmData({
      'type': 'event_sync',
      'title': 't',
      'body': 'b',
    });
    expect(entry, isNull);
  });
}
```

- [ ] **Step 2: 테스트 실행해서 실패 확인**

Run: `flutter test test/services/notification_history_service_test.dart`
Expected: FAIL — 파일 없음

- [ ] **Step 3: 구현**

`lib/services/notification_history_service.dart`:
```dart
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationHistoryEntry {
  final String? id;
  final String title;
  final String body;
  final String eventId;
  final DateTime? receivedAt;

  const NotificationHistoryEntry({
    this.id,
    required this.title,
    required this.body,
    required this.eventId,
    this.receivedAt,
  });

  /// FCM data 페이로드(문자열 맵)에서 알림기록 항목을 만든다.
  /// event_sync 타입이 아니거나 eventId가 없으면 기록하지 않는다(null).
  static NotificationHistoryEntry? fromFcmData(Map<String, dynamic> data) {
    if (data['type'] != 'event_sync') return null;
    final eventId = data['eventId'] as String? ?? '';
    if (eventId.isEmpty) return null;
    return NotificationHistoryEntry(
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      eventId: eventId,
    );
  }

  factory NotificationHistoryEntry.fromDoc(String id, Map<String, dynamic> map) {
    return NotificationHistoryEntry(
      id: id,
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      eventId: map['eventId'] as String? ?? '',
      receivedAt: (map['receivedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'body': body,
      'eventId': eventId,
      'receivedAt': FieldValue.serverTimestamp(),
    };
  }
}

class NotificationHistoryService {
  static const _maxEntries = 50;

  final FirebaseFirestore _db;
  NotificationHistoryService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _collection(String uid) =>
      _db.collection('users').doc(uid).collection('notificationHistory');

  Future<void> record(String uid, NotificationHistoryEntry entry) async {
    await _collection(uid).add(entry.toMap());

    final overflow = await _collection(uid)
        .orderBy('receivedAt', descending: true)
        .get();
    if (overflow.docs.length <= _maxEntries) return;
    final batch = _db.batch();
    for (final doc in overflow.docs.skip(_maxEntries)) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Stream<List<NotificationHistoryEntry>> streamFor(String uid) {
    return _collection(uid)
        .orderBy('receivedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => NotificationHistoryEntry.fromDoc(d.id, d.data()))
            .toList());
  }
}
```

- [ ] **Step 4: 테스트 실행해서 통과 확인**

Run: `flutter test test/services/notification_history_service_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: main.dart FCM 핸들러에 기록 로직 연결**

`_firebaseMessagingBackgroundHandler`(백그라운드) 안, 기존 `if (message.data['type'] != 'event_sync') return;` 라인 **앞**에 기록 로직을 추가한다 — 동기화가 실패해도 기록은 남도록 순서를 바꾼다:
```dart
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await _recordNotificationHistory(message);
  if (message.data['type'] != 'event_sync') return;
  try {
    // ... 기존 동기화 로직 그대로 유지
```

`_initFcm()` 안의 `FirebaseMessaging.onMessage.listen` 콜백을 아래로 교체:
```dart
  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    await _recordNotificationHistory(message);
  });
```

파일에 공통 헬퍼 함수 추가 (`_firebaseMessagingBackgroundHandler` 위):
```dart
Future<void> _recordNotificationHistory(RemoteMessage message) async {
  final entry = NotificationHistoryEntry.fromFcmData(message.data);
  if (entry == null) return;
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;
  try {
    await NotificationHistoryService().record(uid, entry);
  } catch (_) {
    // 기록 실패는 조용히 무시 — 알림 자체 수신/동기화는 계속 진행
  }
}
```

`import 'services/notification_history_service.dart';` 추가.

- [ ] **Step 6: 전체 테스트 실행**

Run: `flutter test`
Expected: PASS 전체

- [ ] **Step 7: 커밋**

```bash
git add lib/services/notification_history_service.dart lib/main.dart test/services/notification_history_service_test.dart
git commit -m "feat: 파트너 알림 수신 시 알림기록 저장"
```

---

### Task 8: 알림 기록 화면 + 라우트 + 설정 메뉴

**Files:**
- Create: `lib/screens/settings/notification_history_screen.dart`
- Modify: `lib/router/app_router.dart`
- Modify: `lib/screens/settings/settings_screen.dart`

**Interfaces:**
- Consumes: `NotificationHistoryService.streamFor` (Task 7), `eventsStreamProvider` (기존), `EventDetailScreen`/`EventDetailArgs` (기존)

- [ ] **Step 1: 화면 구현**

`lib/screens/settings/notification_history_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/calendar_provider.dart';
import '../../services/notification_history_service.dart';
import '../event/event_detail_screen.dart' show EventDetailArgs;

final _notificationHistoryProvider =
    StreamProvider<List<NotificationHistoryEntry>>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value(const []);
  return NotificationHistoryService().streamFor(uid);
});

class NotificationHistoryScreen extends ConsumerWidget {
  const NotificationHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(_notificationHistoryProvider);
    final events = ref.watch(eventsStreamProvider).valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('알림 기록')),
      body: entriesAsync.when(
        data: (entries) {
          if (entries.isEmpty) {
            return const Center(child: Text('아직 받은 알림이 없습니다'));
          }
          return ListView.separated(
            itemCount: entries.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final entry = entries[index];
              return ListTile(
                title: Text(entry.title),
                subtitle: Text(entry.body),
                trailing: entry.receivedAt != null
                    ? Text(
                        DateFormat('M/d HH:mm').format(entry.receivedAt!),
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      )
                    : null,
                onTap: () {
                  final event = events.where((e) => e.id == entry.eventId).firstOrNull;
                  if (event == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('삭제된 일정입니다')),
                    );
                    return;
                  }
                  context.push('/event/detail', extra: EventDetailArgs(event: event));
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('불러오지 못했습니다')),
      ),
    );
  }
}
```

`EventDetailArgs`의 실제 생성자 파라미터명(`event`, `occurrenceDate` 등)을 `lib/screens/event/event_detail_screen.dart`에서 확인 후 맞춘다 — `occurrenceDate`가 필수 파라미터면 `null`을 명시적으로 넘긴다.

- [ ] **Step 2: 라우트 추가**

`lib/router/app_router.dart`에 import 추가:
```dart
import '../screens/settings/notification_history_screen.dart';
```
`routes` 리스트의 `/settings/import` 아래에 추가:
```dart
      GoRoute(
        path: '/settings/notifications',
        builder: (context, _) => const NotificationHistoryScreen(),
      ),
```

- [ ] **Step 3: 설정 화면에 메뉴 추가**

`settings_screen.dart`의 "기념일 관리" `ListTile` 바로 아래(테마 섹션 이전 또는 이후, "월간 리포트" 앞)에 추가:
```dart
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('알림 기록'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/notifications'),
          ),
          const Divider(),
```

- [ ] **Step 4: 정적 분석 + 전체 테스트**

Run: `flutter analyze`
Expected: 새 에러 없음
Run: `flutter test`
Expected: PASS 전체

- [ ] **Step 5: 실기기 수동 확인**

두 실기기(본인/파트너)로 일정 생성 → 상대 기기에서 설정 → 알림 기록에 항목 확인, 탭해서 상세화면 이동 확인. 앱 완전 종료 상태에서도(백그라운드 핸들러 경로) 기록되는지 확인.

- [ ] **Step 6: 커밋**

```bash
git add lib/screens/settings/notification_history_screen.dart lib/router/app_router.dart lib/screens/settings/settings_screen.dart
git commit -m "feat: 알림 기록 화면 + 설정 메뉴 추가"
```

---

## Self-Review 결과

- **스펙 커버리지:** 설계 문서의 1(설정 영구저장)→Task 1-3, 2(테마)→Task 4-5, 3(알림기록)→Task 6-8 전부 대응. 마이그레이션 유예 사항(구 prefs 파일 삭제 보류)은 Task 3에 명시적으로 기록해 스펙과의 차이를 남김.
- **플레이스홀더 스캔:** 없음 — 모든 스텝에 실제 코드 포함.
- **타입 일관성:** `NotificationHistoryEntry`, `SettingsMigrationService.fieldsToWrite`, `updateUserSettings` 시그니처가 정의 태스크와 사용 태스크 간에 동일하게 유지됨을 확인.
