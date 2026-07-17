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
