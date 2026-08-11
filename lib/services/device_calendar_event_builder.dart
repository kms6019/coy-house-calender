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

/// 기기 이벤트에 심는 앱 이벤트 식별자.
///
/// Android CalendarProvider 의 CUSTOM_APP_URI 로 저장된다(device_calendar 의
/// [Event.url]). 매핑(SharedPreferences)이 유실돼도 이 값으로 기존 항목을
/// 찾아 재사용할 수 있어, 같은 일정을 다시 만들지 않는다.
String coyEventMarker(String firestoreEventId) =>
    'coyhouse://event/$firestoreEventId';

/// [url] 이 앱이 심은 마커면 Firestore 이벤트 id, 아니면 null.
String? firestoreIdFromMarker(String? url) {
  const prefix = 'coyhouse://event/';
  if (url == null || !url.startsWith(prefix)) return null;
  final id = url.substring(prefix.length).trim();
  return id.isEmpty ? null : id;
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
    url: Uri.tryParse(coyEventMarker(event.id)),
  );
}
