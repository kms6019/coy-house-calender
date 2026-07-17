# 아침 브리핑 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 설정 시각(기본 08:00)에 오늘 일정 요약 로컬 알림 — 7일 선스케줄, 일정 없는 날 스킵, 기기별 설정.

**Architecture:** 순수 함수 `briefingBody`(내용 생성) + `BriefingPrefs`(SharedPreferences) + `NotificationService.scheduleBriefings`(7일 취소 후 재스케줄, 날짜 기반 고정 ID) + `alarmSyncProvider` 편승 재계산 + 설정 화면 `_BriefingSection`.

**Tech Stack:** Flutter + Riverpod 2.x + flutter_local_notifications + shared_preferences(^2.5.2, 이미 의존성 있음) + timezone.

**Spec:** `docs/superpowers/specs/2026-07-17-morning-briefing-design.md`

## Global Constraints

- 일정 0건인 날은 스케줄 스킵. 브리핑 시각이 이미 지난 날도 스킵.
- SharedPreferences 키: `briefing_enabled`(bool, 기본 false), `briefing_hour`(int, 기본 8), `briefing_minute`(int, 기본 0).
- 알림 채널: id `briefing_channel`, 이름 `아침 브리핑`.
- 본문 형식: 최대 3건 `아이콘 제목 (HH:mm)` 콤마 연결, 종일은 `(종일)`, 초과분 ` 외 N건`. 제목 `오늘의 일정 N건`.
- 브리핑 알림 ID = `'briefing-yyyyMMdd'.hashCode.abs()` (날짜 기반 고정).
- 테스트 import `package:coy_house_calender/...`. Flutter PATH: `$env:PATH += ";C:\flutter_windows_3.41.6-stable\flutter\bin"`.
- 커밋: conventional commits 한국어 제목.

---

### Task 1: briefingBody 순수 함수 + BriefingPrefs (TDD)

**Files:**
- Create: `lib/utils/briefing_utils.dart`
- Create: `lib/services/briefing_prefs.dart`
- Test: `test/utils/briefing_utils_test.dart` (신규)

**Interfaces:**
- Produces: `class BriefingContent { final String title; final String body; }`
- Produces: `BriefingContent? briefingBody(List<EventModel> dayEvents)` — 빈 리스트면 null
- Produces: `class BriefingPrefs { final bool enabled; final int hour; final int minute; }` + `static Future<BriefingPrefs> load()` + `static Future<void> save({required bool enabled, required int hour, required int minute})`

- [ ] **Step 1: 실패하는 테스트 작성**

`test/utils/briefing_utils_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:coy_house_calender/models/event_model.dart';
import 'package:coy_house_calender/utils/briefing_utils.dart';

EventModel _event(String title,
    {String? icon, bool allDay = false, int hour = 9, int minute = 0}) {
  return EventModel(
    id: 'id-$title',
    coupleId: 'c1',
    createdByUid: 'u1',
    title: title,
    startDateTime: DateTime(2026, 7, 18, hour, minute),
    isAllDay: allDay,
    color: 0xFF42A5F5,
    hasAlarm: false,
    alarmMinutesBefore: 30,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    icon: icon,
  );
}

void main() {
  test('빈 리스트는 null', () {
    expect(briefingBody([]), isNull);
  });

  test('1건: 제목/본문 형식', () {
    final c = briefingBody([_event('회의', hour: 14, minute: 30)])!;
    expect(c.title, '오늘의 일정 1건');
    expect(c.body, '회의 (14:30)');
  });

  test('종일은 (종일), 이모지는 prefix', () {
    final c = briefingBody([_event('생일', icon: '🎂', allDay: true)])!;
    expect(c.body, '🎂 생일 (종일)');
  });

  test('3건까지 콤마 연결', () {
    final c = briefingBody([
      _event('a', hour: 9),
      _event('b', hour: 10),
      _event('c', hour: 11),
    ])!;
    expect(c.title, '오늘의 일정 3건');
    expect(c.body, 'a (09:00), b (10:00), c (11:00)');
  });

  test('4건이면 외 1건', () {
    final c = briefingBody([
      _event('a', hour: 9),
      _event('b', hour: 10),
      _event('c', hour: 11),
      _event('d', hour: 12),
    ])!;
    expect(c.title, '오늘의 일정 4건');
    expect(c.body, 'a (09:00), b (10:00), c (11:00) 외 1건');
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/utils/briefing_utils_test.dart`
Expected: FAIL (briefing_utils.dart 없음)

- [ ] **Step 3: 구현**

`lib/utils/briefing_utils.dart`:

```dart
import 'package:intl/intl.dart';
import '../models/event_model.dart';

class BriefingContent {
  final String title;
  final String body;
  const BriefingContent({required this.title, required this.body});
}

/// 하루 일정 요약. 빈 리스트면 null (브리핑 스킵).
BriefingContent? briefingBody(List<EventModel> dayEvents) {
  if (dayEvents.isEmpty) return null;
  final timeFmt = DateFormat('HH:mm');
  final parts = dayEvents.take(3).map((e) {
    final name = e.icon != null ? '${e.icon} ${e.title}' : e.title;
    final time = e.isAllDay ? '종일' : timeFmt.format(e.startDateTime);
    return '$name ($time)';
  }).join(', ');
  final extra =
      dayEvents.length > 3 ? ' 외 ${dayEvents.length - 3}건' : '';
  return BriefingContent(
    title: '오늘의 일정 ${dayEvents.length}건',
    body: '$parts$extra',
  );
}
```

`lib/services/briefing_prefs.dart`:

```dart
import 'package:shared_preferences/shared_preferences.dart';

/// 아침 브리핑 기기별 설정
class BriefingPrefs {
  final bool enabled;
  final int hour;
  final int minute;
  const BriefingPrefs({
    required this.enabled,
    required this.hour,
    required this.minute,
  });

  static Future<BriefingPrefs> load() async {
    final p = await SharedPreferences.getInstance();
    return BriefingPrefs(
      enabled: p.getBool('briefing_enabled') ?? false,
      hour: p.getInt('briefing_hour') ?? 8,
      minute: p.getInt('briefing_minute') ?? 0,
    );
  }

  static Future<void> save({
    required bool enabled,
    required int hour,
    required int minute,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('briefing_enabled', enabled);
    await p.setInt('briefing_hour', hour);
    await p.setInt('briefing_minute', minute);
  }
}
```

- [ ] **Step 4: 통과 확인**

Run: `flutter test`
Expected: 전체 PASS

- [ ] **Step 5: 커밋**

```bash
git add lib/utils/briefing_utils.dart lib/services/briefing_prefs.dart test/utils/briefing_utils_test.dart
git commit -m "feat: 아침 브리핑 내용 생성 및 설정 저장 유틸"
```

---

### Task 2: scheduleBriefings + 재계산 훅

**Files:**
- Modify: `lib/services/notification_service.dart`
- Modify: `lib/providers/calendar_provider.dart` (alarmSyncProvider)

**Interfaces:**
- Consumes: `briefingBody` (Task 1), `BriefingPrefs.load()` (Task 1), `eventsForDay` (lib/utils/event_utils.dart)
- Produces: `NotificationService.scheduleBriefings({required List<EventModel> events, required bool enabled, required int hour, required int minute})` — 8일치 취소 후, enabled면 오늘부터 7일 스케줄

- [ ] **Step 1: NotificationService에 브리핑 메서드 추가**

`lib/services/notification_service.dart` — import 추가:

```dart
import '../utils/briefing_utils.dart';
import '../utils/event_utils.dart';
```

클래스에 추가 (`cancelAlarm` 위):

```dart
  int _briefingId(DateTime day) {
    final ymd =
        '${day.year}${day.month.toString().padLeft(2, '0')}${day.day.toString().padLeft(2, '0')}';
    return 'briefing-$ymd'.hashCode.abs();
  }

  /// 아침 브리핑 재스케줄: 8일치 취소 후 enabled면 오늘부터 7일 등록.
  /// 일정 없는 날·이미 지난 시각은 스킵.
  Future<void> scheduleBriefings({
    required List<EventModel> events,
    required bool enabled,
    required int hour,
    required int minute,
  }) async {
    if (!_supported) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (var i = 0; i < 8; i++) {
      await _plugin.cancel(_briefingId(today.add(Duration(days: i))));
    }
    if (!enabled) return;

    for (var i = 0; i < 7; i++) {
      final day = today.add(Duration(days: i));
      final when = DateTime(day.year, day.month, day.day, hour, minute);
      if (when.isBefore(now)) continue;
      final content = briefingBody(eventsForDay(events, day));
      if (content == null) continue;
      try {
        await _plugin.zonedSchedule(
          _briefingId(day),
          content.title,
          content.body,
          tz.TZDateTime.from(when, tz.local),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'briefing_channel',
              '아침 브리핑',
              channelDescription: '오늘의 일정 요약',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (_) {
        // 권한 없음 등 — 알람과 동일하게 무시
      }
    }
  }
```

- [ ] **Step 2: alarmSyncProvider에 편승**

`lib/providers/calendar_provider.dart` — import 추가 `import '../services/briefing_prefs.dart';`. `alarmSyncProvider` 본문 끝(기존 for 루프 다음)에 추가:

```dart
  // 아침 브리핑 재스케줄 (기기 설정 기반)
  BriefingPrefs.load().then((p) {
    ns.scheduleBriefings(
      events: events,
      enabled: p.enabled,
      hour: p.hour,
      minute: p.minute,
    );
  });
```

- [ ] **Step 3: 검증 + 커밋**

Run: `flutter analyze && flutter test`
Expected: 신규 이슈 0, 전체 PASS

```bash
git add lib/services/notification_service.dart lib/providers/calendar_provider.dart
git commit -m "feat: 아침 브리핑 7일 선스케줄 및 재계산 훅"
```

---

### Task 3: 설정 UI

**Files:**
- Modify: `lib/screens/settings/settings_screen.dart` (기념일 관리 타일의 `const Divider(),` 다음에 섹션 삽입 + 클래스 추가)

**Interfaces:**
- Consumes: `BriefingPrefs`, `NotificationService.scheduleBriefings`, `eventsStreamProvider` (기존)

- [ ] **Step 1: 섹션 위젯 추가**

`lib/screens/settings/settings_screen.dart` — import 추가:

```dart
import '../../services/briefing_prefs.dart';
```

(NotificationService, eventsStreamProvider용 calendar_provider는 이미 import돼 있음 — 없으면 추가.)

기념일 관리 ListTile 뒤의 `const Divider(),` 다음에 삽입:

```dart
          // 아침 브리핑
          const _BriefingSection(),
          const Divider(),
```

파일 하단에 클래스 추가:

```dart
class _BriefingSection extends ConsumerStatefulWidget {
  const _BriefingSection();

  @override
  ConsumerState<_BriefingSection> createState() => _BriefingSectionState();
}

class _BriefingSectionState extends ConsumerState<_BriefingSection> {
  BriefingPrefs? _prefs;

  @override
  void initState() {
    super.initState();
    BriefingPrefs.load().then((p) {
      if (mounted) setState(() => _prefs = p);
    });
  }

  Future<void> _apply({required bool enabled, int? hour, int? minute}) async {
    final h = hour ?? _prefs?.hour ?? 8;
    final m = minute ?? _prefs?.minute ?? 0;
    await BriefingPrefs.save(enabled: enabled, hour: h, minute: m);
    if (!mounted) return;
    setState(() => _prefs = BriefingPrefs(enabled: enabled, hour: h, minute: m));
    final events = ref.read(eventsStreamProvider).valueOrNull ?? [];
    await NotificationService().scheduleBriefings(
      events: events,
      enabled: enabled,
      hour: h,
      minute: m,
    );
  }

  @override
  Widget build(BuildContext context) {
    final prefs = _prefs;
    if (prefs == null) return const SizedBox.shrink();
    return Column(
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.wb_sunny_outlined),
          title: const Text('아침 브리핑'),
          subtitle: const Text('매일 아침 오늘 일정 요약 알림 (일정 없는 날 제외)'),
          value: prefs.enabled,
          onChanged: (v) => _apply(enabled: v),
        ),
        if (prefs.enabled)
          ListTile(
            contentPadding: const EdgeInsets.only(left: 72, right: 16),
            title: const Text('브리핑 시간'),
            trailing: Text(
              '${prefs.hour.toString().padLeft(2, '0')}:${prefs.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 16),
            ),
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime:
                    TimeOfDay(hour: prefs.hour, minute: prefs.minute),
              );
              if (picked != null) {
                _apply(
                    enabled: true, hour: picked.hour, minute: picked.minute);
              }
            },
          ),
      ],
    );
  }
}
```

- [ ] **Step 2: 검증 + 커밋**

Run: `flutter analyze && flutter test`
Expected: 신규 이슈 0, 전체 PASS

수동: 설정 화면에서 스위치 온 → 시간 행 노출 → TimePicker 동작 (통제자가 브라우저/실기기 확인).

```bash
git add lib/screens/settings/settings_screen.dart
git commit -m "feat: 설정에 아침 브리핑 온오프 및 시간 선택 추가"
```
