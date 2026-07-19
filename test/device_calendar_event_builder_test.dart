import 'package:flutter_test/flutter_test.dart';
import 'package:coy_house_calender/models/event_model.dart';
import 'package:coy_house_calender/services/device_calendar_event_builder.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

EventModel _event({
  required DateTime start,
  DateTime? end,
  bool isAllDay = false,
}) {
  return EventModel(
    id: 'e1',
    coupleId: 'c1',
    createdByUid: 'u1',
    title: 't',
    description: '',
    startDateTime: start,
    endDateTime: end,
    isAllDay: isAllDay,
    color: 0xFF000000,
    hasAlarm: false,
    alarmMinutesBefore: 0,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

void main() {
  setUpAll(() {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
  });

  test('종일 이벤트는 UTC 자정 기준으로 변환된다 (KST여도 날짜 안 밀림)', () {
    final e = _event(
      start: DateTime(2026, 7, 22),
      end: DateTime(2026, 7, 22),
      isAllDay: true,
    );
    final device = buildDeviceCalendarEvent(e, calendarId: 'cal');
    expect(device.start, tz.TZDateTime.utc(2026, 7, 22));
    // 삼성캘린더는 DTEND 날짜를 그대로 종료일로 표시 — 종료일 자정 그대로
    expect(device.end, tz.TZDateTime.utc(2026, 7, 22));
  });

  test('종일 이벤트 end 없으면 시작일 하루짜리', () {
    final e = _event(start: DateTime(2026, 7, 22), isAllDay: true);
    final device = buildDeviceCalendarEvent(e, calendarId: 'cal');
    expect(device.start, tz.TZDateTime.utc(2026, 7, 22));
    expect(device.end, tz.TZDateTime.utc(2026, 7, 22));
  });

  test('시간 지정 이벤트는 로컬 타임존 유지', () {
    final e = _event(
      start: DateTime(2026, 7, 22, 14, 0),
      end: DateTime(2026, 7, 22, 15, 0),
    );
    final device = buildDeviceCalendarEvent(e, calendarId: 'cal');
    expect(
      device.start,
      tz.TZDateTime.from(DateTime(2026, 7, 22, 14, 0), tz.local),
    );
    expect(
      device.end,
      tz.TZDateTime.from(DateTime(2026, 7, 22, 15, 0), tz.local),
    );
  });
}
