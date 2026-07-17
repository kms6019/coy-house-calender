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
  return Event(
    calendarId,
    eventId: deviceEventId,
    title: event.title,
    description: event.description,
    start: tz.TZDateTime.from(event.startDateTime, tz.local),
    end: tz.TZDateTime.from(end, tz.local),
    allDay: event.isAllDay,
    recurrenceRule: _recurrenceRule(event),
  );
}
