import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:coy_house_calender/services/calendar_event_mapping.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('getDeviceEventId returns null when unset', () async {
    final mapping = CalendarEventMapping();
    expect(await mapping.getDeviceEventId('abc'), isNull);
  });

  test('setDeviceEventId then getDeviceEventId returns saved id', () async {
    final mapping = CalendarEventMapping();
    await mapping.setDeviceEventId('abc', 'device-1');
    expect(await mapping.getDeviceEventId('abc'), 'device-1');
  });

  test('removeDeviceEventId clears mapping', () async {
    final mapping = CalendarEventMapping();
    await mapping.setDeviceEventId('abc', 'device-1');
    await mapping.removeDeviceEventId('abc');
    expect(await mapping.getDeviceEventId('abc'), isNull);
  });

  test('mapping persists multiple keys independently', () async {
    final mapping = CalendarEventMapping();
    await mapping.setDeviceEventId('abc', 'device-1');
    await mapping.setDeviceEventId('xyz', 'device-2');
    expect(await mapping.getDeviceEventId('abc'), 'device-1');
    expect(await mapping.getDeviceEventId('xyz'), 'device-2');
  });

  test('calendar id persists across instances', () async {
    final mapping = CalendarEventMapping();
    await mapping.setCalendarId('cal-1');
    final mapping2 = CalendarEventMapping();
    expect(await mapping2.getCalendarId(), 'cal-1');
  });
}
