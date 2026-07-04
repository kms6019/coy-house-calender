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
