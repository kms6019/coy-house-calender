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

List<EventModel> eventsForDay(List<EventModel> events, DateTime day) {
  final expanded = expandRecurringForRange(events, day, day);
  final result = expanded.where((event) => eventOccursOnDay(event, day)).toList()
    ..sort(compareCalendarEvents);
  return result;
}
