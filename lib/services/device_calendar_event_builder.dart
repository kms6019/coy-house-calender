import 'package:device_calendar/device_calendar.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/event_model.dart';

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

Event buildDeviceCalendarEvent(
  EventModel event, {
  required String calendarId,
  String? deviceEventId,
}) {
  final end = event.endDateTime ?? event.startDateTime;
  // 종일 이벤트는 Android CalendarProvider 규약상 UTC 자정 기준으로 저장해야
  // 날짜가 하루 밀리지 않는다. 삼성캘린더는 DTEND 날짜를 그대로 종료일로
  // 표시하므로(+1일 하면 다음날까지로 보임) 종료일 자정을 그대로 쓴다.
  final tz.TZDateTime startTz;
  final tz.TZDateTime endTz;
  if (event.isAllDay) {
    final s = event.startDateTime;
    startTz = tz.TZDateTime.utc(s.year, s.month, s.day);
    endTz = tz.TZDateTime.utc(end.year, end.month, end.day);
  } else {
    startTz = tz.TZDateTime.from(event.startDateTime, tz.local);
    endTz = tz.TZDateTime.from(end, tz.local);
  }
  return Event(
    calendarId,
    eventId: deviceEventId,
    title: event.title,
    description: event.description,
    start: startTz,
    end: endTz,
    allDay: event.isAllDay,
    recurrenceRule: _recurrenceRule(event),
  );
}
