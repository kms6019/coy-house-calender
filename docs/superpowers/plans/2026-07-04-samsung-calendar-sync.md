# Samsung 캘린더 동기화 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** CoyHouseCalender 앱에서 생성/수정/삭제한 이벤트를 기기의 "CoyHouseCalender"라는 전용 네이티브 캘린더(삼성캘린더/AOSP CalendarProvider)에 단방향 자동 동기화한다.

**Architecture:** `device_calendar` 플러그인을 감싸는 `SamsungCalendarSyncService`를 만들고, Firestore eventId ↔ 기기 캘린더 eventId 매핑은 `shared_preferences`에 로컬 저장한다 (`CalendarEventMapping`). EventModel → device_calendar `Event` 변환은 순수 함수(`buildDeviceCalendarEvent`)로 분리해 단위 테스트 가능하게 만든다. sync 호출은 기존 이벤트 저장/삭제 흐름(`event_form_screen.dart`, `event_detail_screen.dart`) 끝에 추가하고, 실패해도 Firestore 쓰기나 앱 핵심 기능에 영향 없도록 서비스 내부에서 전부 try/catch로 격리한다.

**Tech Stack:** Flutter, `device_calendar` (신규), `shared_preferences` (기존), `timezone` (기존)

## Global Constraints

- 방향: 앱 → 기기 캘린더 단방향만. 기기 캘린더 변경은 앱에 반영 안 함.
- 플랫폼: Android 전용. `kIsWeb`이거나 `!Platform.isAndroid`면 전부 skip.
- 대상 캘린더: 이름이 정확히 `"CoyHouseCalender"`인 전용 로컬 캘린더 하나만 사용.
- sync 실패(퍼미션 거부, 플러그인 에러 등)는 절대 사용자에게 다이얼로그로 노출하지 않고 `debugPrint`로만 로그.
- sync 실패가 Firestore 쓰기/삭제 성공 여부에 영향을 줘서는 안 됨.

---

### Task 1: 이벤트 매핑 로컬 저장소 (CalendarEventMapping)

Firestore eventId ↔ 기기 캘린더 eventId, 그리고 생성된 전용 캘린더 id를 `shared_preferences`에 저장/조회하는 순수 저장소. 플랫폼 채널 없이 순수 Dart + `shared_preferences` mock으로 완전히 단위 테스트 가능.

**Files:**
- Create: `lib/services/calendar_event_mapping.dart`
- Test: `test/services/calendar_event_mapping_test.dart`

**Interfaces:**
- Produces: `class CalendarEventMapping` with methods:
  - `Future<String?> getDeviceEventId(String firestoreEventId)`
  - `Future<void> setDeviceEventId(String firestoreEventId, String deviceEventId)`
  - `Future<void> removeDeviceEventId(String firestoreEventId)`
  - `Future<String?> getCalendarId()`
  - `Future<void> setCalendarId(String calendarId)`

- [ ] **Step 1: Write the failing tests**

```dart
// test/services/calendar_event_mapping_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:coy_house_calender/services/calendar_event_mapping.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('getDeviceEventId returns null when unset', () async {
    final mapping = CalendarEventMapping();
    expect(await mapping.getDeviceEventId('abc'), isNull);
  });

  test('setDeviceEventId then getDeviceEventId returns saved id', () async {
    final mapping = CalendarEventMapping();
    await mapping.setDeviceEventId('abc', 'device-1');
    expect(await mapping.getDeviceEventId('abc'), 'device-1');
  });

  test('removeDeviceEventId clears mapping', () async {
    final mapping = CalendarEventMapping();
    await mapping.setDeviceEventId('abc', 'device-1');
    await mapping.removeDeviceEventId('abc');
    expect(await mapping.getDeviceEventId('abc'), isNull);
  });

  test('mapping persists multiple keys independently', () async {
    final mapping = CalendarEventMapping();
    await mapping.setDeviceEventId('abc', 'device-1');
    await mapping.setDeviceEventId('xyz', 'device-2');
    expect(await mapping.getDeviceEventId('abc'), 'device-1');
    expect(await mapping.getDeviceEventId('xyz'), 'device-2');
  });

  test('calendar id persists across instances', () async {
    final mapping = CalendarEventMapping();
    await mapping.setCalendarId('cal-1');
    final mapping2 = CalendarEventMapping();
    expect(await mapping2.getCalendarId(), 'cal-1');
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/services/calendar_event_mapping_test.dart`
Expected: FAIL — `Error: Not found: 'package:coy_house_calender/services/calendar_event_mapping.dart'` (file doesn't exist yet)

- [ ] **Step 3: Implement CalendarEventMapping**

```dart
// lib/services/calendar_event_mapping.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CalendarEventMapping {
  static const _mapKey = 'samsung_calendar_event_map';
  static const _calendarIdKey = 'samsung_calendar_id';

  Future<Map<String, String>> _loadMap() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_mapKey);
    if (raw == null) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, v as String));
  }

  Future<void> _saveMap(Map<String, String> map) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_mapKey, jsonEncode(map));
  }

  Future<String?> getDeviceEventId(String firestoreEventId) async {
    final map = await _loadMap();
    return map[firestoreEventId];
  }

  Future<void> setDeviceEventId(String firestoreEventId, String deviceEventId) async {
    final map = await _loadMap();
    map[firestoreEventId] = deviceEventId;
    await _saveMap(map);
  }

  Future<void> removeDeviceEventId(String firestoreEventId) async {
    final map = await _loadMap();
    map.remove(firestoreEventId);
    await _saveMap(map);
  }

  Future<String?> getCalendarId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_calendarIdKey);
  }

  Future<void> setCalendarId(String calendarId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_calendarIdKey, calendarId);
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/services/calendar_event_mapping_test.dart`
Expected: PASS (5 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/services/calendar_event_mapping.dart test/services/calendar_event_mapping_test.dart
git commit -m "feat: 삼성캘린더 동기화용 이벤트 id 매핑 저장소 추가"
```

---

### Task 2: device_calendar 의존성 추가 + EventModel → Event 변환 함수

`device_calendar` 패키지를 프로젝트에 추가하고, Android 권한을 등록한다. `EventModel`을 `device_calendar`의 `Event`로 변환하는 순수 함수를 작성한다 (플러그인 호출 없음 — 플랫폼 채널과 무관하게 단위 테스트 가능).

**Files:**
- Modify: `pubspec.yaml` (add `device_calendar` dependency)
- Modify: `android/app/src/main/AndroidManifest.xml:1-6` (add calendar permissions)
- Create: `lib/services/device_calendar_event_builder.dart`
- Test: `test/services/device_calendar_event_builder_test.dart`

**Interfaces:**
- Consumes: `EventModel` (id, title, description, startDateTime, endDateTime, isAllDay) from `lib/models/event_model.dart`
- Produces: `Event buildDeviceCalendarEvent(EventModel event, {required String calendarId, String? deviceEventId})` — used by Task 3.

- [ ] **Step 1: Add the device_calendar dependency**

Run: `flutter pub add device_calendar`
Expected: `pubspec.yaml` gets a new line under `dependencies:` like `  device_calendar: ^X.Y.Z` and `pubspec.lock` updates.

- [ ] **Step 2: Add Android calendar permissions**

Modify `android/app/src/main/AndroidManifest.xml` — add two lines after the existing `RECEIVE_BOOT_COMPLETED` permission (line 6):

```xml
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <!-- 정확한 알람 (예약 알림) -->
    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
    <!-- 삼성캘린더(기기 네이티브 캘린더) 동기화 -->
    <uses-permission android:name="android.permission.READ_CALENDAR"/>
    <uses-permission android:name="android.permission.WRITE_CALENDAR"/>
```

- [ ] **Step 3: Write the failing tests**

```dart
// test/services/device_calendar_event_builder_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:coy_house_calender/models/event_model.dart';
import 'package:coy_house_calender/services/device_calendar_event_builder.dart';

void main() {
  setUpAll(() {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
  });

  EventModel makeEvent({DateTime? end, bool isAllDay = false}) {
    final start = DateTime(2026, 7, 10, 14, 0);
    return EventModel(
      id: 'evt-1',
      coupleId: 'couple-1',
      createdByUid: 'uid-1',
      title: '테스트 일정',
      description: '메모',
      startDateTime: start,
      endDateTime: end,
      isAllDay: isAllDay,
      color: 0xFF42A5F5,
      hasAlarm: false,
      alarmMinutesBefore: 30,
      createdAt: start,
      updatedAt: start,
    );
  }

  test('maps title/description/allDay/calendarId from EventModel', () {
    final event = makeEvent();
    final result = buildDeviceCalendarEvent(event, calendarId: 'cal-1');
    expect(result.title, '테스트 일정');
    expect(result.description, '메모');
    expect(result.allDay, false);
    expect(result.calendarId, 'cal-1');
  });

  test('uses startDateTime as end when endDateTime is null', () {
    final event = makeEvent(end: null);
    final result = buildDeviceCalendarEvent(event, calendarId: 'cal-1');
    expect(result.end, tz.TZDateTime.from(event.startDateTime, tz.local));
  });

  test('passes deviceEventId through when updating existing event', () {
    final event = makeEvent();
    final result = buildDeviceCalendarEvent(
      event,
      calendarId: 'cal-1',
      deviceEventId: 'dev-99',
    );
    expect(result.eventId, 'dev-99');
  });

  test('eventId is null when creating a new event', () {
    final event = makeEvent();
    final result = buildDeviceCalendarEvent(event, calendarId: 'cal-1');
    expect(result.eventId, isNull);
  });
}
```

- [ ] **Step 4: Run tests to verify they fail**

Run: `flutter test test/services/device_calendar_event_builder_test.dart`
Expected: FAIL — `Error: Not found: 'package:coy_house_calender/services/device_calendar_event_builder.dart'`

- [ ] **Step 5: Implement buildDeviceCalendarEvent**

```dart
// lib/services/device_calendar_event_builder.dart
import 'package:device_calendar/device_calendar.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/event_model.dart';

Event buildDeviceCalendarEvent(
  EventModel event, {
  required String calendarId,
  String? deviceEventId,
}) {
  final end = event.endDateTime ?? event.startDateTime;
  return Event(
    calendarId,
    eventId: deviceEventId,
    title: event.title,
    description: event.description,
    start: tz.TZDateTime.from(event.startDateTime, tz.local),
    end: tz.TZDateTime.from(end, tz.local),
    allDay: event.isAllDay,
  );
}
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `flutter test test/services/device_calendar_event_builder_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 7: Commit**

```bash
git add pubspec.yaml pubspec.lock android/app/src/main/AndroidManifest.xml lib/services/device_calendar_event_builder.dart test/services/device_calendar_event_builder_test.dart
git commit -m "feat: device_calendar 의존성 및 EventModel 변환 함수 추가"
```

---

### Task 3: SamsungCalendarSyncService

Task 1의 매핑 저장소와 Task 2의 변환 함수를 묶어 실제 `device_calendar` 플러그인 호출(캘린더 생성/조회, 이벤트 생성/수정/삭제, 퍼미션 요청)을 감싼다.

이 클래스는 실제 Android CalendarProvider와 통신하는 플랫폼 채널을 직접 호출하므로 `flutter test`(Dart VM, 플랫폼 채널 없음)로는 실행할 수 없다 — Task 5의 실기기 수동 검증으로 커버한다. 대신 이 태스크에서는 `flutter analyze`로 정적 검증만 수행한다.

**Files:**
- Create: `lib/services/samsung_calendar_sync_service.dart`

**Interfaces:**
- Consumes:
  - `CalendarEventMapping` from Task 1 (`getDeviceEventId`, `setDeviceEventId`, `removeDeviceEventId`, `getCalendarId`, `setCalendarId`)
  - `buildDeviceCalendarEvent(EventModel event, {required String calendarId, String? deviceEventId})` from Task 2
- Produces: `class SamsungCalendarSyncService` with methods used by Task 4:
  - `Future<void> syncEventCreate(EventModel event)`
  - `Future<void> syncEventUpdate(EventModel event)`
  - `Future<void> syncEventDelete(String eventId)`

- [ ] **Step 1: Implement SamsungCalendarSyncService**

```dart
// lib/services/samsung_calendar_sync_service.dart
import 'dart:io' show Platform;
import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import '../models/event_model.dart';
import 'calendar_event_mapping.dart';
import 'device_calendar_event_builder.dart';

class SamsungCalendarSyncService {
  static const _calendarName = 'CoyHouseCalender';

  final DeviceCalendarPlugin _plugin;
  final CalendarEventMapping _mapping;

  SamsungCalendarSyncService({
    DeviceCalendarPlugin? plugin,
    CalendarEventMapping? mapping,
  })  : _plugin = plugin ?? DeviceCalendarPlugin(),
        _mapping = mapping ?? CalendarEventMapping();

  bool get _supported => !kIsWeb && Platform.isAndroid;

  Future<String?> _ensureCalendarExists() async {
    final cached = await _mapping.getCalendarId();
    if (cached != null) return cached;

    final hasPermissions = await _plugin.hasPermissions();
    if (hasPermissions.data != true) {
      final requested = await _plugin.requestPermissions();
      if (requested.data != true) return null;
    }

    final calendarsResult = await _plugin.retrieveCalendars();
    final calendars = calendarsResult.data;
    final existing = calendars?.where((c) => c.name == _calendarName).toList();
    if (existing != null && existing.isNotEmpty && existing.first.id != null) {
      final id = existing.first.id!;
      await _mapping.setCalendarId(id);
      return id;
    }

    final createResult = await _plugin.createCalendar(_calendarName);
    final newId = createResult.data;
    if (newId != null) await _mapping.setCalendarId(newId);
    return newId;
  }

  Future<void> syncEventCreate(EventModel event) async {
    if (!_supported) return;
    try {
      final calendarId = await _ensureCalendarExists();
      if (calendarId == null) return;
      final deviceEvent = buildDeviceCalendarEvent(event, calendarId: calendarId);
      final result = await _plugin.createOrUpdateEvent(deviceEvent);
      final deviceEventId = result?.data;
      if (deviceEventId != null) {
        await _mapping.setDeviceEventId(event.id, deviceEventId);
      }
    } catch (e) {
      debugPrint('[SamsungCalendarSync] create error: $e');
    }
  }

  Future<void> syncEventUpdate(EventModel event) async {
    if (!_supported) return;
    try {
      final calendarId = await _ensureCalendarExists();
      if (calendarId == null) return;
      final existingDeviceId = await _mapping.getDeviceEventId(event.id);
      final deviceEvent = buildDeviceCalendarEvent(
        event,
        calendarId: calendarId,
        deviceEventId: existingDeviceId,
      );
      final result = await _plugin.createOrUpdateEvent(deviceEvent);
      final deviceEventId = result?.data;
      if (deviceEventId != null) {
        await _mapping.setDeviceEventId(event.id, deviceEventId);
      }
    } catch (e) {
      debugPrint('[SamsungCalendarSync] update error: $e');
    }
  }

  Future<void> syncEventDelete(String eventId) async {
    if (!_supported) return;
    try {
      final calendarId = await _mapping.getCalendarId();
      final deviceEventId = await _mapping.getDeviceEventId(eventId);
      if (calendarId == null || deviceEventId == null) return;
      await _plugin.deleteEvent(calendarId, deviceEventId);
      await _mapping.removeDeviceEventId(eventId);
    } catch (e) {
      debugPrint('[SamsungCalendarSync] delete error: $e');
    }
  }
}
```

- [ ] **Step 2: Static analysis check**

Run: `flutter analyze lib/services/samsung_calendar_sync_service.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/services/samsung_calendar_sync_service.dart
git commit -m "feat: 삼성캘린더 sync 서비스 (생성/수정/삭제) 추가"
```

---

### Task 4: 이벤트 생성/수정/삭제 흐름에 sync 연결

**Files:**
- Modify: `lib/screens/event/event_form_screen.dart:1-8` (import), `:117-151` (save flow)
- Modify: `lib/screens/event/event_detail_screen.dart:1-8` (import), `:113-117` (delete flow)

**Interfaces:**
- Consumes: `SamsungCalendarSyncService` from Task 3 (`syncEventCreate`, `syncEventUpdate`, `syncEventDelete`)

- [ ] **Step 1: Add sync call to event_form_screen.dart**

Add import after line 8 (`import '../../services/notification_service.dart';`):

```dart
import '../../services/samsung_calendar_sync_service.dart';
```

Modify the `_save()` method — insert the sync call right after `saved` is determined (after line 150 `await fs.updateEvent(saved);` and its enclosing `if/else` block ends), before the existing `String? warningMessage;` line:

```dart
      } else {
        saved = widget.event!.copyWith(
          title: _titleCtrl.text.trim(),
          description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          startDateTime: _startDateTime,
          endDateTime: _endDateTime,
          isAllDay: _isAllDay,
          hasAlarm: _hasAlarm,
          alarmMinutesBefore: _alarmMinutes,
          updatedAt: DateTime.now(),
        );
        await fs.updateEvent(saved);
      }

      final calendarSync = SamsungCalendarSyncService();
      if (widget.event == null) {
        await calendarSync.syncEventCreate(saved);
      } else {
        await calendarSync.syncEventUpdate(saved);
      }

      String? warningMessage;
```

- [ ] **Step 2: Add sync call to event_detail_screen.dart**

Add import after line 8 (`import '../../services/notification_service.dart';`):

```dart
import '../../services/samsung_calendar_sync_service.dart';
```

Modify `_confirmDelete`:

```dart
    if (confirmed == true) {
      await ref.read(firestoreServiceProvider).deleteEvent(event.id);
      await NotificationService().cancelAlarm(event.id);
      await SamsungCalendarSyncService().syncEventDelete(event.id);
      if (context.mounted) context.pop();
    }
```

- [ ] **Step 3: Static analysis check**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 4: Run full test suite**

Run: `flutter test`
Expected: All tests PASS (including Task 1 and Task 2 tests, unaffected by this UI wiring)

- [ ] **Step 5: Commit**

```bash
git add lib/screens/event/event_form_screen.dart lib/screens/event/event_detail_screen.dart
git commit -m "feat: 이벤트 저장/삭제 시 삼성캘린더 동기화 연결"
```

---

### Task 5: 실기기 수동 검증

`device_calendar`는 플랫폼 채널을 쓰므로 Z플립5 실기기(`flutter run -d R3CW70R1BCW`)에서 직접 확인해야 한다.

**Files:** (없음 — 수동 검증만)

- [ ] **Step 1: 앱 실행 및 이벤트 생성 확인**

Run: `flutter run -d R3CW70R1BCW`

앱에서 새 일정 생성 → 권한 요청 다이얼로그가 뜨면 허용 → 저장.
기기의 삼성캘린더 앱을 열어 "CoyHouseCalender"라는 캘린더가 생성되어 있고 방금 만든 일정이 표시되는지 확인.

- [ ] **Step 2: 수정 반영 확인**

앱에서 같은 일정의 제목/시간을 수정 → 저장.
삼성캘린더 앱에서 해당 일정이 새 제목/시간으로 갱신되어 있는지 확인 (중복 생성되지 않아야 함).

- [ ] **Step 3: 삭제 반영 확인**

앱에서 해당 일정 삭제.
삼성캘린더 앱에서 해당 일정이 사라졌는지 확인.

- [ ] **Step 4: 퍼미션 거부 시나리오**

앱 설정에서 캘린더 권한을 거부 상태로 변경 (또는 최초 요청 시 거부) 후 새 일정 생성.
앱이 크래시 없이 정상 저장되고(Firestore에는 반영됨), 삼성캘린더에는 반영되지 않는지 확인. 에러 다이얼로그가 뜨지 않아야 함.

- [ ] **Step 5: 결과 기록**

네 가지 시나리오 모두 통과하면 `docs/superpowers/plans/2026-07-04-samsung-calendar-sync.md`의 이 태스크 체크박스를 전부 체크하고 커밋.

```bash
git add docs/superpowers/plans/2026-07-04-samsung-calendar-sync.md
git commit -m "docs: 삼성캘린더 동기화 실기기 검증 완료 체크"
```
