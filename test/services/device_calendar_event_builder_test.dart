import 'package:flutter_test/flutter_test.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:coy_house_calender/models/event_model.dart';
import 'package:coy_house_calender/services/device_calendar_event_builder.dart';

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
}
