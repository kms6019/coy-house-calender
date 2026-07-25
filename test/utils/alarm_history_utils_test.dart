import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coy_house_calender/models/event_model.dart';
import 'package:coy_house_calender/utils/alarm_history_utils.dart';

EventModel _event({
  String id = 'e1',
  String title = 't',
  required DateTime start,
  DateTime? end,
  bool hasAlarm = true,
  int alarmMinutesBefore = 30,
  String repeat = 'none',
  DateTime? until,
  List<DateTime> excluded = const [],
}) {
  return EventModel.fromMap({
    'id': id,
    'coupleId': 'c1',
    'createdByUid': 'u1',
    'title': title,
    'description': null,
    'startDateTime': Timestamp.fromDate(start),
    'endDateTime': end != null ? Timestamp.fromDate(end) : null,
    'isAllDay': false,
    'color': 0xFF42A5F5,
    'hasAlarm': hasAlarm,
    'alarmMinutesBefore': alarmMinutesBefore,
    'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
    'updatedAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
    'repeat': repeat,
    'repeatUntil': until != null ? Timestamp.fromDate(until) : null,
    'excludedDates': excluded.map(Timestamp.fromDate).toList(),
  });
}

void main() {
  final now = DateTime(2026, 7, 25, 12, 0);

  group('pastAlarms', () {
    test('hasAlarm이 false인 이벤트는 제외된다', () {
      final e = _event(
        start: DateTime(2026, 7, 25, 9),
        hasAlarm: false,
      );

      expect(pastAlarms([e], now), isEmpty);
    });

    test('알람 시각은 시작 - alarmMinutesBefore로 계산된다', () {
      final e = _event(
        start: DateTime(2026, 7, 25, 9),
        alarmMinutesBefore: 30,
      );

      final out = pastAlarms([e], now);
      expect(out.length, 1);
      expect(out.first.alarmAt, DateTime(2026, 7, 25, 8, 30));
      expect(out.first.event.id, 'e1');
    });

    test('아직 울리지 않은 미래 알람은 제외된다', () {
      final e = _event(
        start: DateTime(2026, 7, 25, 18),
        alarmMinutesBefore: 30,
      );

      expect(pastAlarms([e], now), isEmpty);
    });

    test('withinDays보다 오래된 알람은 제외된다', () {
      final e = _event(
        start: DateTime(2026, 6, 1, 9),
        alarmMinutesBefore: 0,
      );

      expect(pastAlarms([e], now, withinDays: 30), isEmpty);
    });

    test('반복 이벤트의 지난 회차가 각각 항목이 된다', () {
      // 매주 월요일 10:00, 시작 2026-07-06(월). now=7/25(토)
      // 지난 회차: 7/6, 7/13, 7/20
      final e = _event(
        start: DateTime(2026, 7, 6, 10),
        alarmMinutesBefore: 10,
        repeat: 'weekly',
      );

      final out = pastAlarms([e], now);
      expect(
        out.map((a) => a.alarmAt),
        [
          DateTime(2026, 7, 20, 9, 50),
          DateTime(2026, 7, 13, 9, 50),
          DateTime(2026, 7, 6, 9, 50),
        ],
      );
    });

    test('excludedDates에 걸린 회차는 제외된다', () {
      final e = _event(
        start: DateTime(2026, 7, 6, 10),
        alarmMinutesBefore: 10,
        repeat: 'weekly',
        excluded: [DateTime(2026, 7, 13)],
      );

      final out = pastAlarms([e], now);
      expect(
        out.map((a) => a.alarmAt),
        [
          DateTime(2026, 7, 20, 9, 50),
          DateTime(2026, 7, 6, 9, 50),
        ],
      );
    });

    test('repeatUntil 이후 회차는 제외된다', () {
      final e = _event(
        start: DateTime(2026, 7, 6, 10),
        alarmMinutesBefore: 10,
        repeat: 'weekly',
        until: DateTime(2026, 7, 14),
      );

      final out = pastAlarms([e], now);
      expect(
        out.map((a) => a.alarmAt),
        [
          DateTime(2026, 7, 13, 9, 50),
          DateTime(2026, 7, 6, 9, 50),
        ],
      );
    });

    test('알람은 지났지만 일정 시작이 미래면 포함된다', () {
      // 시작 13:00, 알람 120분 전 = 11:00 (now=12:00 이므로 이미 울림)
      final e = _event(
        start: DateTime(2026, 7, 25, 13),
        alarmMinutesBefore: 120,
      );

      final out = pastAlarms([e], now);
      expect(out.length, 1);
      expect(out.first.alarmAt, DateTime(2026, 7, 25, 11));
    });

    test('결과는 alarmAt 내림차순으로 정렬된다', () {
      final older = _event(
        id: 'older',
        start: DateTime(2026, 7, 20, 9),
        alarmMinutesBefore: 0,
      );
      final newer = _event(
        id: 'newer',
        start: DateTime(2026, 7, 24, 9),
        alarmMinutesBefore: 0,
      );

      final out = pastAlarms([older, newer], now);
      expect(out.map((a) => a.event.id), ['newer', 'older']);
    });
  });
}
