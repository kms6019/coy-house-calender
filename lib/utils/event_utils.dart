import 'package:flutter/material.dart';

import '../models/event_model.dart';

DateTime calendarDateKey(DateTime date) => DateUtils.dateOnly(date);

bool eventOccursOnDay(EventModel event, DateTime day) {
  final target = calendarDateKey(day);
  final start = calendarDateKey(event.startDateTime);
  final end = calendarDateKey(event.endDateTime ?? event.startDateTime);

  return !target.isBefore(start) && !target.isAfter(end);
}

bool isMultiDayEvent(EventModel event) {
  final start = calendarDateKey(event.startDateTime);
  final end = calendarDateKey(event.endDateTime ?? event.startDateTime);
  return end.isAfter(start);
}

int compareCalendarEvents(EventModel a, EventModel b) {
  if (a.isAllDay != b.isAllDay) return a.isAllDay ? -1 : 1;

  final startComparison = a.startDateTime.compareTo(b.startDateTime);
  if (startComparison != 0) return startComparison;

  final titleComparison = a.title.compareTo(b.title);
  if (titleComparison != 0) return titleComparison;

  return a.id.compareTo(b.id);
}

List<EventModel> eventsForDay(List<EventModel> events, DateTime day) {
  final result = events.where((event) => eventOccursOnDay(event, day)).toList()
    ..sort(compareCalendarEvents);
  return result;
}
