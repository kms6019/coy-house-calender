import 'package:flutter_test/flutter_test.dart';
import 'package:coy_house_calender/models/event_model.dart';
import 'package:coy_house_calender/utils/briefing_utils.dart';

EventModel _event(String title,
    {String? icon, bool allDay = false, int hour = 9, int minute = 0}) {
  return EventModel(
    id: 'id-$title',
    coupleId: 'c1',
    createdByUid: 'u1',
    title: title,
    startDateTime: DateTime(2026, 7, 18, hour, minute),
    isAllDay: allDay,
    color: 0xFF42A5F5,
    hasAlarm: false,
    alarmMinutesBefore: 30,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    icon: icon,
  );
}

void main() {
  test('빈 리스트는 null', () {
    expect(briefingBody([]), isNull);
  });

  test('1건: 제목/본문 형식', () {
    final c = briefingBody([_event('회의', hour: 14, minute: 30)])!;
    expect(c.title, '오늘의 일정 1건');
    expect(c.body, '회의 (14:30)');
  });

  test('종일은 (종일), 이모지는 prefix', () {
    final c = briefingBody([_event('생일', icon: '🎂', allDay: true)])!;
    expect(c.body, '🎂 생일 (종일)');
  });

  test('3건까지 콤마 연결', () {
    final c = briefingBody([
      _event('a', hour: 9),
      _event('b', hour: 10),
      _event('c', hour: 11),
    ])!;
    expect(c.title, '오늘의 일정 3건');
    expect(c.body, 'a (09:00), b (10:00), c (11:00)');
  });

  test('4건이면 외 1건', () {
    final c = briefingBody([
      _event('a', hour: 9),
      _event('b', hour: 10),
      _event('c', hour: 11),
      _event('d', hour: 12),
    ])!;
    expect(c.title, '오늘의 일정 4건');
    expect(c.body, 'a (09:00), b (10:00), c (11:00) 외 1건');
  });
}
