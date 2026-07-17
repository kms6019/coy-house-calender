# 반복 일정 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 이벤트에 매일/매주/매월/매년 반복 규칙 추가 — 마스터 1문서 + 조회 시 범위 전개(materialization).

**Architecture:** `events` 문서에 `repeat`/`repeatUntil`/`excludedDates` 필드 추가. 순수 함수 `expandRecurringForRange`가 마스터를 보이는 범위의 occurrence 복사본(같은 id, 날짜 이동)으로 전개 — 캘린더 그리드는 월 범위 전개본, 일별 시트·홈위젯은 `eventsForDay` 내부 전개로 자동 반영. 알림은 `nextOccurrence`로 다음 회차 1건만 스케줄. 삼성캘린더는 device_calendar `RecurrenceRule`로 반복 전달.

**Tech Stack:** Flutter + Riverpod 2.x + cloud_firestore, flutter_local_notifications, device_calendar, timezone.

**Spec:** `docs/superpowers/specs/2026-07-17-recurring-events-design.md`

## Global Constraints

- 패키지명 `coy_house_calender` — 테스트 import는 `package:coy_house_calender/...`.
- Firestore events 쓰기는 기존 패턴 유지 (`updateEvent`는 `update()`, couples/users만 merge set).
- monthly는 그 달에 없는 날짜 스킵(31일→2월 없음), yearly 2/29는 평년 스킵. `repeatUntil`은 **포함**.
- `excludedDates` 날짜는 자정 정규화(`calendarDateKey`) 후 저장/비교.
- 기존 문서(반복 필드 없음) → `repeat: 'none'` 취급, 동작 불변. 알 수 없는 repeat 문자열도 `none`.
- UI 문구 한국어. 기존 코드 스타일(ConsumerWidget 등) 따름.
- Flutter PATH: PowerShell에서 `$env:PATH += ";C:\flutter_windows_3.41.6-stable\flutter\bin"` 선행.
- lint: `(_, __)` 파라미터는 `(_, _)` 사용 (unnecessary_underscores).
- 커밋 메시지: conventional commits, 한국어 제목.

---

### Task 1: EventModel 반복 필드 (TDD)

**Files:**
- Modify: `lib/models/event_model.dart`
- Test: `test/models/event_model_test.dart` (신규)

**Interfaces:**
- Produces: `enum RepeatRule { none, daily, weekly, monthly, yearly }` (event_model.dart 내 선언)
- Produces: `EventModel.repeat` (RepeatRule, 기본 none), `EventModel.repeatUntil` (DateTime?), `EventModel.excludedDates` (List<DateTime>, 기본 const [])
- Produces: `EventModel.copyWithRepeat({required RepeatRule repeat, required DateTime? repeatUntil, List<DateTime>? excludedDates})` — repeatUntil을 null로 **덮어쓸 수 있는** 명시적 메서드 (기존 copyWith는 null 병합이라 해제 불가)

- [ ] **Step 1: 실패하는 테스트 작성**

`test/models/event_model_test.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coy_house_calender/models/event_model.dart';

Map<String, dynamic> _baseMap() => {
      'id': 'e1',
      'coupleId': 'c1',
      'createdByUid': 'u1',
      'title': '쓰레기 버리기',
      'description': null,
      'startDateTime': Timestamp.fromDate(DateTime(2026, 7, 6, 20, 0)),
      'endDateTime': null,
      'isAllDay': false,
      'color': 0xFF42A5F5,
      'hasAlarm': false,
      'alarmMinutesBefore': 30,
      'createdAt': Timestamp.fromDate(DateTime(2026, 7, 1)),
      'updatedAt': Timestamp.fromDate(DateTime(2026, 7, 1)),
    };

void main() {
  test('반복 필드 없는 구 문서는 repeat none, 빈 excludedDates', () {
    final e = EventModel.fromMap(_baseMap());
    expect(e.repeat, RepeatRule.none);
    expect(e.repeatUntil, isNull);
    expect(e.excludedDates, isEmpty);
  });

  test('알 수 없는 repeat 문자열은 none 취급', () {
    final e = EventModel.fromMap(_baseMap()..['repeat'] = 'biweekly');
    expect(e.repeat, RepeatRule.none);
  });

  test('반복 필드 직렬화 왕복', () {
    final map = _baseMap()
      ..['repeat'] = 'weekly'
      ..['repeatUntil'] = Timestamp.fromDate(DateTime(2026, 12, 31))
      ..['excludedDates'] = [Timestamp.fromDate(DateTime(2026, 7, 13))];
    final e = EventModel.fromMap(map);
    expect(e.repeat, RepeatRule.weekly);
    expect(e.repeatUntil, DateTime(2026, 12, 31));
    expect(e.excludedDates, [DateTime(2026, 7, 13)]);

    final out = e.toMap();
    expect(out['repeat'], 'weekly');
    expect((out['repeatUntil'] as Timestamp).toDate(), DateTime(2026, 12, 31));
    expect((out['excludedDates'] as List).length, 1);
  });

  test('copyWithRepeat는 repeatUntil을 null로 덮어쓸 수 있다', () {
    final e = EventModel.fromMap(_baseMap()
      ..['repeat'] = 'daily'
      ..['repeatUntil'] = Timestamp.fromDate(DateTime(2026, 12, 31)));
    final cleared = e.copyWithRepeat(repeat: RepeatRule.daily, repeatUntil: null);
    expect(cleared.repeatUntil, isNull);
    expect(cleared.repeat, RepeatRule.daily);
    expect(cleared.id, e.id);
  });

  test('copyWithRepeat로 excludedDates 추가', () {
    final e = EventModel.fromMap(_baseMap()..['repeat'] = 'weekly');
    final updated = e.copyWithRepeat(
      repeat: e.repeat,
      repeatUntil: e.repeatUntil,
      excludedDates: [DateTime(2026, 7, 13)],
    );
    expect(updated.excludedDates, [DateTime(2026, 7, 13)]);
  });

  test('기존 copyWith는 반복 필드를 보존한다', () {
    final e = EventModel.fromMap(_baseMap()
      ..['repeat'] = 'monthly'
      ..['excludedDates'] = [Timestamp.fromDate(DateTime(2026, 8, 6))]);
    final copied = e.copyWith(title: '월급날');
    expect(copied.repeat, RepeatRule.monthly);
    expect(copied.excludedDates.length, 1);
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/models/event_model_test.dart`
Expected: FAIL (컴파일 에러 — `RepeatRule` 없음)

- [ ] **Step 3: EventModel 수정**

`lib/models/event_model.dart` — 클래스 위에 enum 추가:

```dart
enum RepeatRule { none, daily, weekly, monthly, yearly }
```

필드 3개 추가:

```dart
  final RepeatRule repeat;
  final DateTime? repeatUntil;
  final List<DateTime> excludedDates;
```

생성자에 (required 아님):

```dart
    this.repeat = RepeatRule.none,
    this.repeatUntil,
    this.excludedDates = const [],
```

`fromMap`에 추가:

```dart
      repeat: RepeatRule.values.asNameMap()[map['repeat'] as String? ?? 'none'] ??
          RepeatRule.none,
      repeatUntil: map['repeatUntil'] != null
          ? (map['repeatUntil'] as Timestamp).toDate()
          : null,
      excludedDates: (map['excludedDates'] as List?)
              ?.whereType<Timestamp>()
              .map((t) => t.toDate())
              .toList() ??
          const [],
```

`toMap`에 추가:

```dart
      'repeat': repeat.name,
      'repeatUntil':
          repeatUntil != null ? Timestamp.fromDate(repeatUntil!) : null,
      'excludedDates': excludedDates.map(Timestamp.fromDate).toList(),
```

기존 `copyWith` 본문의 `EventModel(...)` 생성 인자에 반복 필드 보존 추가:

```dart
      repeat: repeat,
      repeatUntil: repeatUntil,
      excludedDates: excludedDates,
```

클래스에 메서드 추가:

```dart
  /// repeatUntil을 null로 덮어쓸 수 있는 반복 전용 copy (copyWith는 null 병합이라 해제 불가)
  EventModel copyWithRepeat({
    required RepeatRule repeat,
    required DateTime? repeatUntil,
    List<DateTime>? excludedDates,
  }) {
    return EventModel(
      id: id,
      coupleId: coupleId,
      createdByUid: createdByUid,
      title: title,
      description: description,
      startDateTime: startDateTime,
      endDateTime: endDateTime,
      isAllDay: isAllDay,
      color: color,
      hasAlarm: hasAlarm,
      alarmMinutesBefore: alarmMinutesBefore,
      createdAt: createdAt,
      updatedAt: updatedAt,
      repeat: repeat,
      repeatUntil: repeatUntil,
      excludedDates: excludedDates ?? this.excludedDates,
    );
  }
```

- [ ] **Step 4: 통과 확인**

Run: `flutter test test/models/event_model_test.dart`
Expected: PASS (6개)

- [ ] **Step 5: 커밋**

```bash
git add lib/models/event_model.dart test/models/event_model_test.dart
git commit -m "feat: EventModel에 반복 규칙 필드 추가"
```

---

### Task 2: 반복 전개 유틸 (TDD)

**Files:**
- Modify: `lib/utils/event_utils.dart`
- Test: `test/utils/event_utils_test.dart` (신규)

**Interfaces:**
- Consumes: `RepeatRule`, `EventModel` 반복 필드 (Task 1)
- Produces: `List<EventModel> expandRecurringForRange(List<EventModel> events, DateTime rangeStart, DateTime rangeEnd)` — repeat==none은 통과, 반복은 범위 내 occurrence 복사본(같은 id, start/end 날짜 이동·시각/기간 유지)
- Produces: `DateTime? nextOccurrence(EventModel event, DateTime after)` — after 이후(초과) 첫 occurrence 시작 DateTime, 없으면 null
- Produces: `eventsForDay`가 내부에서 전개 수행 (시그니처 불변)

- [ ] **Step 1: 실패하는 테스트 작성**

`test/utils/event_utils_test.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coy_house_calender/models/event_model.dart';
import 'package:coy_house_calender/utils/event_utils.dart';

EventModel _event({
  String id = 'e1',
  required DateTime start,
  DateTime? end,
  String repeat = 'none',
  DateTime? until,
  List<DateTime> excluded = const [],
}) {
  return EventModel.fromMap({
    'id': id,
    'coupleId': 'c1',
    'createdByUid': 'u1',
    'title': 't',
    'description': null,
    'startDateTime': Timestamp.fromDate(start),
    'endDateTime': end != null ? Timestamp.fromDate(end) : null,
    'isAllDay': false,
    'color': 0xFF42A5F5,
    'hasAlarm': false,
    'alarmMinutesBefore': 30,
    'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
    'updatedAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
    'repeat': repeat,
    'repeatUntil': until != null ? Timestamp.fromDate(until) : null,
    'excludedDates': excluded.map(Timestamp.fromDate).toList(),
  });
}

void main() {
  group('expandRecurringForRange', () {
    test('repeat none은 그대로 통과', () {
      final e = _event(start: DateTime(2026, 7, 6, 10));
      final out = expandRecurringForRange([e], DateTime(2026, 7, 1), DateTime(2026, 7, 31));
      expect(out.length, 1);
      expect(identical(out.first, e), isTrue);
    });

    test('weekly: 7월 한 달간 같은 요일 회차 생성 (월요일 시작)', () {
      // 2026-07-06 = 월요일
      final e = _event(start: DateTime(2026, 7, 6, 20, 0), repeat: 'weekly');
      final out = expandRecurringForRange([e], DateTime(2026, 7, 1), DateTime(2026, 7, 31));
      // 7/6, 7/13, 7/20, 7/27
      expect(out.length, 4);
      expect(out.map((o) => o.startDateTime.day).toList(), [6, 13, 20, 27]);
      expect(out.every((o) => o.startDateTime.hour == 20), isTrue);
      expect(out.every((o) => o.id == 'e1'), isTrue);
    });

    test('시작일 이전 범위엔 회차 없음', () {
      final e = _event(start: DateTime(2026, 7, 6), repeat: 'daily');
      final out = expandRecurringForRange([e], DateTime(2026, 6, 1), DateTime(2026, 6, 30));
      expect(out, isEmpty);
    });

    test('repeatUntil 당일 포함, 이후 제외', () {
      final e = _event(
          start: DateTime(2026, 7, 6), repeat: 'daily', until: DateTime(2026, 7, 8));
      final out = expandRecurringForRange([e], DateTime(2026, 7, 1), DateTime(2026, 7, 31));
      expect(out.map((o) => o.startDateTime.day).toList(), [6, 7, 8]);
    });

    test('excludedDates 회차 스킵', () {
      final e = _event(
          start: DateTime(2026, 7, 6, 20),
          repeat: 'weekly',
          excluded: [DateTime(2026, 7, 13)]);
      final out = expandRecurringForRange([e], DateTime(2026, 7, 1), DateTime(2026, 7, 31));
      expect(out.map((o) => o.startDateTime.day).toList(), [6, 20, 27]);
    });

    test('monthly 31일 시작은 2월 스킵', () {
      final e = _event(start: DateTime(2026, 1, 31), repeat: 'monthly');
      final feb = expandRecurringForRange([e], DateTime(2026, 2, 1), DateTime(2026, 2, 28));
      expect(feb, isEmpty);
      final mar = expandRecurringForRange([e], DateTime(2026, 3, 1), DateTime(2026, 3, 31));
      expect(mar.length, 1);
      expect(mar.first.startDateTime, DateTime(2026, 3, 31));
    });

    test('yearly 2/29는 평년 스킵', () {
      final e = _event(start: DateTime(2024, 2, 29), repeat: 'yearly');
      final y2026 = expandRecurringForRange([e], DateTime(2026, 2, 1), DateTime(2026, 2, 28));
      expect(y2026, isEmpty);
      final y2028 = expandRecurringForRange([e], DateTime(2028, 2, 1), DateTime(2028, 2, 29));
      expect(y2028.length, 1);
    });

    test('멀티데이 반복: 기간 유지, 범위 걸침 포함', () {
      // 2박: 7/6 10:00 ~ 7/8 12:00, weekly
      final e = _event(
          start: DateTime(2026, 7, 6, 10),
          end: DateTime(2026, 7, 8, 12),
          repeat: 'weekly');
      // 7/14~7/16 범위: 7/13 회차(7/13~7/15)가 걸침
      final out = expandRecurringForRange([e], DateTime(2026, 7, 14), DateTime(2026, 7, 16));
      expect(out.length, 1);
      expect(out.first.startDateTime, DateTime(2026, 7, 13, 10));
      expect(out.first.endDateTime, DateTime(2026, 7, 15, 12));
    });
  });

  group('nextOccurrence', () {
    test('none: 미래면 시작시각, 과거면 null', () {
      final e = _event(start: DateTime(2026, 7, 20, 10));
      expect(nextOccurrence(e, DateTime(2026, 7, 17)), DateTime(2026, 7, 20, 10));
      expect(nextOccurrence(e, DateTime(2026, 7, 21)), isNull);
    });

    test('weekly: 다음 같은 요일 시각', () {
      final e = _event(start: DateTime(2026, 7, 6, 20), repeat: 'weekly');
      expect(nextOccurrence(e, DateTime(2026, 7, 17)), DateTime(2026, 7, 20, 20));
    });

    test('당일 시각 이전이면 당일 반환, 이후면 다음 회차', () {
      final e = _event(start: DateTime(2026, 7, 6, 20), repeat: 'daily');
      expect(nextOccurrence(e, DateTime(2026, 7, 17, 19)), DateTime(2026, 7, 17, 20));
      expect(nextOccurrence(e, DateTime(2026, 7, 17, 21)), DateTime(2026, 7, 18, 20));
    });

    test('until 넘어가면 null, excluded는 건너뜀', () {
      final e = _event(
          start: DateTime(2026, 7, 6, 20),
          repeat: 'weekly',
          until: DateTime(2026, 7, 27),
          excluded: [DateTime(2026, 7, 20)]);
      expect(nextOccurrence(e, DateTime(2026, 7, 17)), DateTime(2026, 7, 27, 20));
      expect(nextOccurrence(e, DateTime(2026, 7, 27, 21)), isNull);
    });
  });

  group('eventsForDay 반복 통합', () {
    test('반복 이벤트가 해당 요일에 나타난다', () {
      final e = _event(start: DateTime(2026, 7, 6, 20), repeat: 'weekly');
      final on20 = eventsForDay([e], DateTime(2026, 7, 20));
      expect(on20.length, 1);
      expect(on20.first.startDateTime, DateTime(2026, 7, 20, 20));
      expect(eventsForDay([e], DateTime(2026, 7, 21)), isEmpty);
    });
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/utils/event_utils_test.dart`
Expected: FAIL (`expandRecurringForRange` 없음)

- [ ] **Step 3: event_utils 구현**

`lib/utils/event_utils.dart`에 추가 (기존 함수 유지):

```dart
bool _matchesRule(RepeatRule rule, DateTime startDay, DateTime day) {
  switch (rule) {
    case RepeatRule.daily:
      return true;
    case RepeatRule.weekly:
      return day.weekday == startDay.weekday;
    case RepeatRule.monthly:
      return day.day == startDay.day;
    case RepeatRule.yearly:
      return day.month == startDay.month && day.day == startDay.day;
    case RepeatRule.none:
      return false;
  }
}

EventModel _occurrenceCopy(EventModel event, DateTime day) {
  final s = event.startDateTime;
  final newStart = DateTime(day.year, day.month, day.day, s.hour, s.minute);
  final newEnd = event.endDateTime != null
      ? newStart.add(event.endDateTime!.difference(s))
      : null;
  return event.copyWith(startDateTime: newStart, endDateTime: newEnd);
}

/// 반복 이벤트를 [rangeStart, rangeEnd] 범위의 occurrence 복사본으로 전개.
/// repeat == none 이벤트는 그대로 통과. 복사본은 마스터와 같은 id.
List<EventModel> expandRecurringForRange(
    List<EventModel> events, DateTime rangeStart, DateTime rangeEnd) {
  final rs = calendarDateKey(rangeStart);
  final re = calendarDateKey(rangeEnd);
  final result = <EventModel>[];

  for (final event in events) {
    if (event.repeat == RepeatRule.none) {
      result.add(event);
      continue;
    }
    final startDay = calendarDateKey(event.startDateTime);
    final durationDays = calendarDateKey(event.endDateTime ?? event.startDateTime)
        .difference(startDay)
        .inDays;
    final until =
        event.repeatUntil != null ? calendarDateKey(event.repeatUntil!) : null;
    final excluded = event.excludedDates.map(calendarDateKey).toSet();

    // 멀티데이가 범위에 걸치도록 시작 커서를 기간만큼 앞으로 패딩
    var day = rs.subtract(Duration(days: durationDays));
    if (day.isBefore(startDay)) day = startDay;
    final last = (until != null && until.isBefore(re)) ? until : re;

    while (!day.isAfter(last)) {
      if (_matchesRule(event.repeat, startDay, day) && !excluded.contains(day)) {
        result.add(_occurrenceCopy(event, day));
      }
      day = day.add(const Duration(days: 1));
    }
  }
  return result;
}

/// [after] 이후(초과) 첫 occurrence의 시작 DateTime. 반복 종료/과거 단건이면 null.
DateTime? nextOccurrence(EventModel event, DateTime after) {
  if (event.repeat == RepeatRule.none) {
    return event.startDateTime.isAfter(after) ? event.startDateTime : null;
  }
  final startDay = calendarDateKey(event.startDateTime);
  final until =
      event.repeatUntil != null ? calendarDateKey(event.repeatUntil!) : null;
  final excluded = event.excludedDates.map(calendarDateKey).toSet();

  var day = calendarDateKey(after);
  if (day.isBefore(startDay)) day = startDay;

  // yearly 2/29(윤년 전용) 대비 넉넉히 탐색 (4년+)
  for (var i = 0; i < 1500; i++) {
    if (until != null && day.isAfter(until)) return null;
    if (_matchesRule(event.repeat, startDay, day) && !excluded.contains(day)) {
      final s = event.startDateTime;
      final candidate = DateTime(day.year, day.month, day.day, s.hour, s.minute);
      if (candidate.isAfter(after)) return candidate;
    }
    day = day.add(const Duration(days: 1));
  }
  return null;
}
```

기존 `eventsForDay`를 교체:

```dart
List<EventModel> eventsForDay(List<EventModel> events, DateTime day) {
  final expanded = expandRecurringForRange(events, day, day);
  final result = expanded.where((event) => eventOccursOnDay(event, day)).toList()
    ..sort(compareCalendarEvents);
  return result;
}
```

- [ ] **Step 4: 통과 확인 (기존 테스트 포함 전체)**

Run: `flutter test`
Expected: 전체 PASS

- [ ] **Step 5: 커밋**

```bash
git add lib/utils/event_utils.dart test/utils/event_utils_test.dart
git commit -m "feat: 반복 일정 범위 전개 및 다음 회차 계산 유틸"
```

---

### Task 3: 이벤트 폼 반복 입력

**Files:**
- Modify: `lib/screens/event/event_form_screen.dart`

**Interfaces:**
- Consumes: `RepeatRule`, `copyWithRepeat` (Task 1)
- Produces: 폼에서 `repeat`/`repeatUntil` 입력·저장. repeat==none이면 repeatUntil은 null, excludedDates는 빈 리스트로 초기화(반복 해제 시 잔여 예외 제거).

- [ ] **Step 1: 상태 필드와 초기화 추가**

`_EventFormScreenState`에 필드 추가 (`_alarmMinutes` 아래):

```dart
  RepeatRule _repeat = RepeatRule.none;
  DateTime? _repeatUntil;
```

라벨 상수 추가 (`_alarmLabels` 아래):

```dart
  static const _repeatLabels = {
    RepeatRule.none: '반복 없음',
    RepeatRule.daily: '매일',
    RepeatRule.weekly: '매주',
    RepeatRule.monthly: '매월',
    RepeatRule.yearly: '매년',
  };
```

`initState`의 `if (widget.event != null) {` 블록 안에 추가:

```dart
      _repeat = widget.event!.repeat;
      _repeatUntil = widget.event!.repeatUntil;
```

- [ ] **Step 2: 저장 로직에 반복 반영**

`_save()`의 신규 생성 `EventModel(` draft에 인자 추가 (`updatedAt: DateTime.now(),` 다음):

```dart
          repeat: _repeat,
          repeatUntil: _repeat == RepeatRule.none ? null : _repeatUntil,
```

수정 경로는 `saved = widget.event!.copyWith(...)` 직후에 한 줄 추가:

```dart
        saved = saved.copyWithRepeat(
          repeat: _repeat,
          repeatUntil: _repeat == RepeatRule.none ? null : _repeatUntil,
          excludedDates:
              _repeat == RepeatRule.none ? const [] : widget.event!.excludedDates,
        );
```

- [ ] **Step 3: UI — 반복 선택 + 종료일**

`build()`의 알림 SwitchListTile 위 (`const Divider(),` 종료 섹션 끝난 직후)에 삽입:

```dart
            // 반복
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.repeat),
              title: const Text('반복'),
              trailing: DropdownButton<RepeatRule>(
                value: _repeat,
                underline: const SizedBox.shrink(),
                items: RepeatRule.values
                    .map((r) => DropdownMenuItem(
                          value: r,
                          child: Text(_repeatLabels[r]!),
                        ))
                    .toList(),
                onChanged: (v) => setState(() {
                  _repeat = v ?? RepeatRule.none;
                  if (_repeat == RepeatRule.none) _repeatUntil = null;
                }),
              ),
            ),
            if (_repeat != RepeatRule.none)
              ListTile(
                contentPadding: const EdgeInsets.only(left: 40),
                title: Text(_repeatUntil != null
                    ? '종료: ${dateFmtShort.format(_repeatUntil!)}'
                    : '반복 종료일 (선택 안 함 = 계속 반복)'),
                trailing: _repeatUntil != null
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setState(() => _repeatUntil = null),
                      )
                    : null,
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _repeatUntil ?? _startDate,
                    firstDate: _startDate, // 시작일 이전 방지
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) setState(() => _repeatUntil = picked);
                },
              ),
            const Divider(),
```

- [ ] **Step 4: 검증**

Run: `flutter analyze`
Expected: No issues found

Run: `flutter test`
Expected: 전체 PASS

- [ ] **Step 5: 커밋**

```bash
git add lib/screens/event/event_form_screen.dart
git commit -m "feat: 이벤트 폼에 반복 규칙 입력 추가"
```

---

### Task 4: 상세 화면 — 회차 전달, 반복 표시, 3-way 삭제

**Files:**
- Modify: `lib/screens/event/event_detail_screen.dart`
- Modify: `lib/router/app_router.dart:68-74` (detail 라우트)
- Modify: `lib/screens/event/event_list_tile.dart:37` (push extra)

**Interfaces:**
- Consumes: `RepeatRule`, `copyWithRepeat` (Task 1), `calendarDateKey` (기존 event_utils)
- Produces: `class EventDetailArgs { final EventModel event; final DateTime occurrenceDate; }` (event_detail_screen.dart에 선언, 라우터/타일이 import)
- 주의: 타일이 넘기는 `event`는 **occurrence 복사본**(날짜 이동됨, id는 마스터와 동일). 상세 화면은 수정/삭제 시 `eventsStreamProvider`에서 **id로 마스터를 조회**해 사용한다 — 복사본으로 updateEvent 하면 마스터 시작일이 회차 날짜로 덮여 이전 회차가 사라진다.

- [ ] **Step 1: EventDetailArgs + 상세 화면 수정**

`lib/screens/event/event_detail_screen.dart` — import에 `../../utils/event_utils.dart` 추가. 클래스 위에 선언:

```dart
class EventDetailArgs {
  final EventModel event; // occurrence 복사본 (표시용)
  final DateTime occurrenceDate; // 열어본 회차 날짜 (자정)
  const EventDetailArgs({required this.event, required this.occurrenceDate});
}
```

`EventDetailScreen`에 필드 추가:

```dart
  final DateTime? occurrenceDate;
  const EventDetailScreen({super.key, required this.event, this.occurrenceDate});
```

`build()` 첫 부분에 마스터 조회 추가 (`currentUid` 줄 다음):

```dart
    // 반복 이벤트의 event는 occurrence 복사본 — 수정/삭제는 마스터 기준
    final master = ref
            .watch(eventsStreamProvider)
            .valueOrNull
            ?.firstWhere((e) => e.id == event.id, orElse: () => event) ??
        event;
```

수정 버튼의 push를 마스터로 교체:

```dart
              onPressed: () => context.push('/event/edit', extra: master),
```

삭제 버튼 교체:

```dart
              onPressed: () => _confirmDelete(context, ref, master),
```

반복 정보 행 추가 — `if (event.hasAlarm) ...[` 블록 앞에:

```dart
          if (master.repeat != RepeatRule.none) ...[
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.repeat,
              label: '반복',
              value: _repeatText(master),
            ),
          ],
```

클래스에 헬퍼 추가:

```dart
  String _repeatText(EventModel master) {
    const labels = {
      RepeatRule.daily: '매일',
      RepeatRule.weekly: '매주',
      RepeatRule.monthly: '매월',
      RepeatRule.yearly: '매년',
    };
    final base = '${labels[master.repeat]} 반복';
    if (master.repeatUntil == null) return base;
    return '$base · ${DateFormat('yyyy.MM.dd').format(master.repeatUntil!)}까지';
  }
```

`_confirmDelete`를 통째로 교체:

```dart
  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, EventModel master) async {
    if (master.repeat == RepeatRule.none) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('일정 삭제'),
          content: const Text('이 일정을 삭제하시겠습니까?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('취소')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('삭제'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await _deleteAll(context, ref, master);
      return;
    }

    // 반복 이벤트: 이 회차만 / 전체
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('반복 일정 삭제'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'one'),
            child: const Text('이 일정만 삭제'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'all'),
            child: const Text('모든 반복 일정 삭제'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
        ],
      ),
    );
    if (choice == null) return;

    if (choice == 'all') {
      await _deleteAll(context, ref, master);
      return;
    }

    // 이 회차만: excludedDates에 추가 (삼성캘린더 미반영 — v1 한계)
    final day =
        calendarDateKey(occurrenceDate ?? event.startDateTime);
    final updated = master.copyWithRepeat(
      repeat: master.repeat,
      repeatUntil: master.repeatUntil,
      excludedDates: [...master.excludedDates, day],
    );
    await ref.read(firestoreServiceProvider).updateEvent(updated);
    // 다음 알림이 이 회차였을 수 있으니 재스케줄
    await NotificationService().cancelAlarm(master.id);
    if (master.hasAlarm) await NotificationService().scheduleAlarm(updated);
    if (context.mounted) context.pop();
  }

  Future<void> _deleteAll(
      BuildContext context, WidgetRef ref, EventModel master) async {
    await ref.read(firestoreServiceProvider).deleteEvent(master.id);
    await NotificationService().cancelAlarm(master.id);
    await SamsungCalendarSyncService().syncEventDelete(master.id);
    if (context.mounted) context.pop();
  }
```

- [ ] **Step 2: 라우터/타일 연결 + 반복 아이콘**

`lib/router/app_router.dart` — import 추가:

```dart
import '../screens/event/event_detail_screen.dart' show EventDetailScreen, EventDetailArgs;
```

(기존 `event_detail_screen.dart` import 줄을 위 형태로 교체)

`/event/detail` 라우트 builder 교체:

```dart
      GoRoute(
        path: '/event/detail',
        builder: (_, state) {
          final extra = state.extra;
          if (extra is EventDetailArgs) {
            return EventDetailScreen(
                event: extra.event, occurrenceDate: extra.occurrenceDate);
          }
          final event = extra as EventModel; // 하위호환
          return EventDetailScreen(event: event);
        },
      ),
```

`lib/screens/event/event_list_tile.dart` — import 추가:

```dart
import '../../utils/event_utils.dart';
import 'event_detail_screen.dart' show EventDetailArgs;
```

`onTap` 교체:

```dart
      onTap: () => context.push(
        '/event/detail',
        extra: EventDetailArgs(
          event: event,
          occurrenceDate: calendarDateKey(event.startDateTime),
        ),
      ),
```

`trailing` 교체 (반복 아이콘 추가):

```dart
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (event.repeat != RepeatRule.none)
            Icon(Icons.repeat, size: 16, color: Colors.grey[500]),
          if (event.hasAlarm)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(Icons.notifications_outlined,
                  size: 16, color: Colors.grey[500]),
            ),
        ],
      ),
```

- [ ] **Step 3: 검증**

Run: `flutter analyze && flutter test`
Expected: No issues, 전체 PASS

- [ ] **Step 4: 커밋**

```bash
git add lib/screens/event/event_detail_screen.dart lib/router/app_router.dart lib/screens/event/event_list_tile.dart
git commit -m "feat: 반복 일정 상세 표시 및 이 회차만/전체 삭제"
```

---

### Task 5: 캘린더 그리드 반복 전개

**Files:**
- Modify: `lib/screens/calendar/calendar_screen.dart:22,158-163`

**Interfaces:**
- Consumes: `expandRecurringForRange` (Task 2)
- 주의: `MonthGrid`는 이벤트 start/end로 자체 배치 계산 — 반드시 전개된 리스트를 넘겨야 반복 회차가 그리드에 보인다. `MonthGrid` 내부는 무수정.

- [ ] **Step 1: calendar_screen에서 월 범위 전개**

`build()`의 `final events = ...` 줄 다음에 추가:

```dart
    final monthStart = DateTime(focusedDay.year, focusedDay.month, 1);
    final monthEnd = DateTime(focusedDay.year, focusedDay.month + 1, 0);
    final expandedEvents = expandRecurringForRange(events, monthStart, monthEnd);
```

`MonthGrid(` 호출의 `events: events,`를 `events: expandedEvents,`로 교체.

(참고: `_DaySheet`는 `eventsForDay` 사용 — Task 2에서 이미 전개됨. `widget_service.dart`도 `eventsForDay` 경유라 무수정.)

- [ ] **Step 2: 검증**

Run: `flutter analyze && flutter test`
Expected: No issues, 전체 PASS

수동: `flutter run -d web-server --web-port 8080` → 반복 일정 생성 → 그리드에 매주 회차 표시 확인 (통제자가 Orca 탭으로 확인).

- [ ] **Step 3: 커밋**

```bash
git add lib/screens/calendar/calendar_screen.dart
git commit -m "feat: 캘린더 그리드에 반복 일정 회차 전개"
```

---

### Task 6: 알림 다음 회차 스케줄 + 삼성캘린더 RecurrenceRule (TDD: builder)

**Files:**
- Modify: `lib/services/notification_service.dart:40-70` (scheduleAlarm)
- Modify: `lib/providers/calendar_provider.dart` (alarmSyncProvider 추가)
- Modify: `lib/screens/calendar/calendar_screen.dart:25` (watch 추가)
- Modify: `lib/services/device_calendar_event_builder.dart`
- Test: `test/services/device_calendar_event_builder_test.dart` (기존 확장)

**Interfaces:**
- Consumes: `nextOccurrence` (Task 2), `RepeatRule` (Task 1)
- Produces: `scheduleAlarm`이 반복 이벤트면 다음 회차 기준 1건 스케줄. `alarmSyncProvider` — 이벤트 스트림 변화 시 hasAlarm 이벤트 전부 재스케줄(앱 실행 시 포함). `buildDeviceCalendarEvent`가 `recurrenceRule` 채움.

- [ ] **Step 1: builder 실패 테스트 추가**

`test/services/device_calendar_event_builder_test.dart`의 `main()` 안에 테스트 추가 (파일 상단에 아래 헬퍼도 추가 — 기존 헬퍼와 이름 충돌 시 이 이름 유지):

```dart
EventModel _recurringModel({RepeatRule repeat = RepeatRule.none, DateTime? until}) {
  return EventModel(
    id: 'e-rec',
    coupleId: 'c1',
    createdByUid: 'u1',
    title: '반복 테스트',
    startDateTime: DateTime(2026, 7, 6, 10),
    endDateTime: DateTime(2026, 7, 6, 11),
    isAllDay: false,
    color: 0xFF42A5F5,
    hasAlarm: false,
    alarmMinutesBefore: 30,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    repeat: repeat,
    repeatUntil: until,
  );
}
```

```dart
  test('반복 없는 이벤트는 recurrenceRule null', () {
    final built = buildDeviceCalendarEvent(_recurringModel(), calendarId: '6');
    expect(built.recurrenceRule, isNull);
  });

  test('weekly 반복은 Weekly RecurrenceRule로 매핑', () {
    final built = buildDeviceCalendarEvent(
      _recurringModel(repeat: RepeatRule.weekly, until: DateTime(2026, 12, 31)),
      calendarId: '6',
    );
    expect(built.recurrenceRule, isNotNull);
    expect(built.recurrenceRule!.recurrenceFrequency, RecurrenceFrequency.Weekly);
    expect(built.recurrenceRule!.endDate, DateTime(2026, 12, 31));
  });
```

**구현 전 확인**: 설치된 device_calendar 버전의 `RecurrenceRule` 생성자·필드명을 pub cache에서 확인할 것 (`~\AppData\Local\Pub\Cache\hosted\pub.dev\device_calendar-*\lib\src\models\recurrence_rule.dart`). 필드명이 다르면 (예: `recurrenceFrequency` vs `frequency`) 실제 API에 맞춰 테스트/구현 모두 조정하고 보고서에 명시.

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/services/device_calendar_event_builder_test.dart`
Expected: FAIL

- [ ] **Step 3: builder 구현**

`lib/services/device_calendar_event_builder.dart`:

```dart
RecurrenceRule? _recurrenceRule(EventModel event) {
  final RecurrenceFrequency freq;
  switch (event.repeat) {
    case RepeatRule.none:
      return null;
    case RepeatRule.daily:
      freq = RecurrenceFrequency.Daily;
    case RepeatRule.weekly:
      freq = RecurrenceFrequency.Weekly;
    case RepeatRule.monthly:
      freq = RecurrenceFrequency.Monthly;
    case RepeatRule.yearly:
      freq = RecurrenceFrequency.Yearly;
  }
  return RecurrenceRule(freq, interval: 1, endDate: event.repeatUntil);
}
```

`buildDeviceCalendarEvent`의 `Event(` 인자에 `recurrenceRule: _recurrenceRule(event),` 추가. (실제 API 필드명 기준으로 조정)

- [ ] **Step 4: scheduleAlarm 반복 지원**

`lib/services/notification_service.dart` — import 추가 `../utils/event_utils.dart`. `scheduleAlarm` 상단을 교체:

```dart
  Future<void> scheduleAlarm(EventModel event) async {
    if (!_supported || !event.hasAlarm) return;

    DateTime? occurrenceStart;
    if (event.repeat == RepeatRule.none) {
      occurrenceStart = event.startDateTime;
    } else {
      // 반복: 다음 회차 1건만 스케줄
      occurrenceStart = nextOccurrence(event, DateTime.now());
      if (occurrenceStart != null &&
          occurrenceStart
              .subtract(Duration(minutes: event.alarmMinutesBefore))
              .isBefore(DateTime.now())) {
        occurrenceStart = nextOccurrence(event, occurrenceStart);
      }
    }
    if (occurrenceStart == null) return;

    final alarmTime = occurrenceStart.subtract(
      Duration(minutes: event.alarmMinutesBefore),
    );
    if (alarmTime.isBefore(DateTime.now())) return;
```

(이하 `body`/`zonedSchedule` 부분은 기존 그대로.)

- [ ] **Step 5: alarmSyncProvider**

`lib/providers/calendar_provider.dart` — import 추가 `../services/notification_service.dart`. `widgetSyncProvider` 아래 추가:

```dart
// 이벤트 변화 시(앱 실행 포함) 알림 재스케줄 — 반복 이벤트의 다음 회차 갱신용
final alarmSyncProvider = Provider<void>((ref) {
  final events = ref.watch(eventsStreamProvider).valueOrNull;
  if (events == null) return;
  final ns = NotificationService();
  for (final event in events) {
    ns.cancelAlarm(event.id).then((_) {
      if (event.hasAlarm) ns.scheduleAlarm(event);
    });
  }
});
```

`lib/screens/calendar/calendar_screen.dart`의 `ref.watch(widgetSyncProvider);` 다음 줄에:

```dart
    ref.watch(alarmSyncProvider);
```

- [ ] **Step 6: 전체 검증**

Run: `flutter test && flutter analyze`
Expected: 전체 PASS, No issues

- [ ] **Step 7: 커밋**

```bash
git add lib/services/notification_service.dart lib/providers/calendar_provider.dart lib/screens/calendar/calendar_screen.dart lib/services/device_calendar_event_builder.dart test/services/device_calendar_event_builder_test.dart
git commit -m "feat: 반복 일정 알림 다음 회차 스케줄 및 삼성캘린더 RecurrenceRule 동기화"
```
