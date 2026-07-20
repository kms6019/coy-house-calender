import 'package:flutter_test/flutter_test.dart';
import 'package:coy_house_calender/services/notification_history_service.dart';

void main() {
  test('fromFcmData parses event_sync payload', () {
    final entry = NotificationHistoryEntry.fromFcmData({
      'type': 'event_sync',
      'eventId': 'ev1',
      'title': '철수님이 일정을 등록했어요',
      'body': '여행 · 7월 22일 (수) 종일',
    });
    expect(entry, isNotNull);
    expect(entry!.eventId, 'ev1');
    expect(entry.title, '철수님이 일정을 등록했어요');
    expect(entry.body, '여행 · 7월 22일 (수) 종일');
  });

  test('fromFcmData returns null for non event_sync payload', () {
    final entry = NotificationHistoryEntry.fromFcmData({'type': 'other'});
    expect(entry, isNull);
  });

  test('fromFcmData returns null when eventId missing', () {
    final entry = NotificationHistoryEntry.fromFcmData({
      'type': 'event_sync',
      'title': 't',
      'body': 'b',
    });
    expect(entry, isNull);
  });
}
