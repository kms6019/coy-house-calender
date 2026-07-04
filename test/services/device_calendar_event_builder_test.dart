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
