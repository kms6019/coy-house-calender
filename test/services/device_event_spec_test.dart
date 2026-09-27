import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coy_house_calender/models/event_model.dart';
import 'package:coy_house_calender/services/device_calendar_event_builder.dart';
import 'package:flutter_test/flutter_test.dart';

EventModel _event({
  required DateTime start,
  DateTime? end,
  bool allDay = false,
  String repeat = 'none',
  DateTime? until,
  List<DateTime> excluded = const [],
}) {
  return EventModel.fromMap({
    'id': 'ev1',
    'coupleId': 'c1',
    'createdByUid': 'u1',
    'title': '회의',
    'description': '설명',
    'startDateTime': Timestamp.fromDate(start),
    'endDateTime': end != null ? Timestamp.fromDate(end) : null,
    'isAllDay': allDay,
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
  group('마커', () {
    test('앱이 심은 uri 에서 Firestore id 를 뽑는다', () {
      expect(firestoreIdFromMarker(coyEventMarker('ev1')), 'ev1');
    });

    test('앱이 심지 않은 uri 는 null', () {
      expect(firestoreIdFromMarker('https://example.com'), isNull);
      expect(firestoreIdFromMarker(null), isNull);
      expect(firestoreIdFromMarker('coyhouse://event/'), isNull);
    });
  });

  group('buildDeviceEventSpec', () {
    test('시각 지정 일정은 로컬 시간대로 그대로 넘긴다', () {
      final start = DateTime(2026, 8, 12, 14);
      final spec = buildDeviceEventSpec(
        _event(start: start, end: DateTime(2026, 8, 12, 15)),
      );
      expect(spec.allDay, isFalse);
      expect(spec.timeZone, 'Asia/Seoul');
      expect(spec.dtstart, start.millisecondsSinceEpoch);
    });

    // 종일은 UTC 자정으로 넣어야 날짜가 하루 밀리지 않는다.
    test('종일 일정은 UTC 자정 기준', () {
      final spec = buildDeviceEventSpec(
        _event(start: DateTime(2026, 8, 12), allDay: true),
      );
      expect(spec.allDay, isTrue);
      expect(spec.timeZone, 'UTC');
      expect(spec.dtstart, DateTime.utc(2026, 8, 12).millisecondsSinceEpoch);
    });

    test('종일 일정의 종료는 다음날 자정(exclusive)', () {
      final spec = buildDeviceEventSpec(
        _event(
          start: DateTime(2026, 8, 12),
          end: DateTime(2026, 8, 14),
          allDay: true,
        ),
      );
      expect(spec.dtend, DateTime.utc(2026, 8, 15).millisecondsSinceEpoch);
    });

    test('반복 없으면 rrule 은 null', () {
      final spec = buildDeviceEventSpec(_event(start: DateTime(2026, 8, 12)));
      expect(spec.rrule, isNull);
    });

    test('반복 규칙을 RRULE 로 만든다', () {
      final spec = buildDeviceEventSpec(
        _event(start: DateTime(2026, 8, 12), repeat: 'weekly'),
      );
      expect(spec.rrule, 'FREQ=WEEKLY');
    });

    test('종료일이 있으면 UNTIL 을 붙인다', () {
      final spec = buildDeviceEventSpec(
        _event(
          start: DateTime(2026, 8, 12),
          repeat: 'daily',
          until: DateTime.utc(2026, 9, 1),
        ),
      );
      expect(spec.rrule, 'FREQ=DAILY;UNTIL=20260901T235959Z');
    });
  });

  group('EXDATE', () {
    test('반복이 아니거나 제외일이 없으면 null', () {
      expect(buildDeviceEventSpec(_event(start: DateTime(2026, 7, 1, 9))).exdate, isNull);
      expect(
        buildDeviceEventSpec(
          _event(start: DateTime(2026, 7, 1, 9), repeat: 'weekly'),
        ).exdate,
        isNull,
      );
    });

    test('시각 일정은 그 회차의 시작 시각(UTC)으로 뺀다', () {
      final start = DateTime(2026, 7, 1, 9, 30);
      final spec = buildDeviceEventSpec(
        _event(
          start: start,
          end: DateTime(2026, 7, 1, 10, 30),
          repeat: 'weekly',
          excluded: [DateTime(2026, 7, 15), DateTime(2026, 7, 8)],
        ),
      );
      String stamp(DateTime t) {
        final u = t.toUtc();
        String two(int v) => v.toString().padLeft(2, '0');
        return '${u.year}${two(u.month)}${two(u.day)}T${two(u.hour)}${two(u.minute)}00Z';
      }
      expect(
        spec.exdate,
        '${stamp(DateTime(2026, 7, 8, 9, 30))},${stamp(DateTime(2026, 7, 15, 9, 30))}',
      );
    });

    test('종일 일정은 UTC 자정으로 뺀다', () {
      final spec = buildDeviceEventSpec(
        _event(
          start: DateTime(2026, 7, 1),
          allDay: true,
          repeat: 'daily',
          excluded: [DateTime(2026, 7, 3)],
        ),
      );
      expect(spec.exdate, '20260703T000000Z');
    });
  });

  test('격주는 WEEKLY;INTERVAL=2', () {
    final spec = buildDeviceEventSpec(
      _event(start: DateTime(2026, 7, 1, 9), repeat: 'biweekly'),
    );
    expect(spec.rrule, 'FREQ=WEEKLY;INTERVAL=2');
  });
}
