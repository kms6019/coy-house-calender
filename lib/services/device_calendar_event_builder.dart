import '../models/event_model.dart';

/// 기기 이벤트에 심는 앱 이벤트 식별자.
///
/// Android CalendarProvider 의 CUSTOM_APP_URI 에 저장된다. 매핑
/// (SharedPreferences)이 유실돼도 이 값으로 기존 항목을 찾아 재사용할 수 있어,
/// 같은 일정을 다시 만들지 않는다.
String coyEventMarker(String firestoreEventId) =>
    'coyhouse://event/$firestoreEventId';

/// [url] 이 앱이 심은 마커면 Firestore 이벤트 id, 아니면 null.
String? firestoreIdFromMarker(String? url) {
  const prefix = 'coyhouse://event/';
  if (url == null || !url.startsWith(prefix)) return null;
  final id = url.substring(prefix.length).trim();
  return id.isEmpty ? null : id;
}

/// CalendarContract.Events 한 행에 쓸 값 묶음.
class DeviceEventSpec {
  final String title;
  final String? description;
  final int dtstart;
  final int dtend;
  final bool allDay;
  final String timeZone;
  final String? rrule;

  const DeviceEventSpec({
    required this.title,
    required this.description,
    required this.dtstart,
    required this.dtend,
    required this.allDay,
    required this.timeZone,
    required this.rrule,
  });
}

String? _rrule(EventModel event) {
  final String freq;
  switch (event.repeat) {
    case RepeatRule.none:
      return null;
    case RepeatRule.daily:
      freq = 'DAILY';
    case RepeatRule.weekly:
      freq = 'WEEKLY';
    case RepeatRule.monthly:
      freq = 'MONTHLY';
    case RepeatRule.yearly:
      freq = 'YEARLY';
  }
  final until = event.repeatUntil;
  if (until == null) return 'FREQ=$freq';
  final u = until.toUtc();
  final stamp =
      '${u.year.toString().padLeft(4, '0')}'
      '${u.month.toString().padLeft(2, '0')}'
      '${u.day.toString().padLeft(2, '0')}T235959Z';
  return 'FREQ=$freq;UNTIL=$stamp';
}

/// 종일 이벤트는 CalendarProvider 규약상 **UTC 자정**으로 저장해야 날짜가
/// 하루 밀리지 않는다. 시각 지정 이벤트는 로컬 시간대를 그대로 쓴다.
DeviceEventSpec buildDeviceEventSpec(EventModel event) {
  final end = event.endDateTime ?? event.startDateTime;
  if (event.isAllDay) {
    final s = event.startDateTime;
    final e = end;
    final start = DateTime.utc(s.year, s.month, s.day);
    // 종일은 종료일 다음날 자정이 exclusive end 다.
    final finish = DateTime.utc(e.year, e.month, e.day)
        .add(const Duration(days: 1));
    return DeviceEventSpec(
      title: event.title,
      description: event.description,
      dtstart: start.millisecondsSinceEpoch,
      dtend: finish.millisecondsSinceEpoch,
      allDay: true,
      timeZone: 'UTC',
      rrule: _rrule(event),
    );
  }
  return DeviceEventSpec(
    title: event.title,
    description: event.description,
    dtstart: event.startDateTime.millisecondsSinceEpoch,
    dtend: end.millisecondsSinceEpoch,
    allDay: false,
    timeZone: 'Asia/Seoul',
    rrule: _rrule(event),
  );
}
