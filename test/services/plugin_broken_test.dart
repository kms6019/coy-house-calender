import 'package:coy_house_calender/services/samsung_calendar_sync_service.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:flutter_test/flutter_test.dart';

Calendar _cal({String? id, String? name}) =>
    Calendar(id: id, name: name);

void main() {
  group('isPluginBroken', () {
    // 실제 사용자 기기: 캘린더 20개가 전부 id/name/accountName null 로 왔다.
    test('모든 캘린더의 id 가 null 이면 손상으로 본다', () {
      final calendars = List.generate(20, (_) => _cal());
      expect(SamsungCalendarSyncService.isPluginBroken(calendars), isTrue);
    });

    test('id 가 하나라도 있으면 정상으로 본다', () {
      final calendars = [
        _cal(),
        _cal(id: '12', name: 'CoyHouseCalender'),
        _cal(),
      ];
      expect(SamsungCalendarSyncService.isPluginBroken(calendars), isFalse);
    });

    test('정상 목록은 손상이 아니다', () {
      final calendars = [
        _cal(id: '1', name: '내 캘린더'),
        _cal(id: '12', name: 'CoyHouseCalender'),
      ];
      expect(SamsungCalendarSyncService.isPluginBroken(calendars), isFalse);
    });

    test('빈 목록은 손상으로 단정하지 않는다 (캘린더가 없을 수도 있다)', () {
      expect(SamsungCalendarSyncService.isPluginBroken([]), isFalse);
    });
  });
}
