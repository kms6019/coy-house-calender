import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coy_house_calender/models/event_model.dart';

Map<String, dynamic> _baseMap() => {
      'id': 'e1',
      'coupleId': 'c1',
      'createdByUid': 'u1',
      'title': '쓰레기 버리기',
      'description': null,
      'startDateTime': Timestamp.fromDate(DateTime(2026, 7, 6, 20, 0)),
      'endDateTime': null,
      'isAllDay': false,
      'color': 0xFF42A5F5,
      'hasAlarm': false,
      'alarmMinutesBefore': 30,
      'createdAt': Timestamp.fromDate(DateTime(2026, 7, 1)),
      'updatedAt': Timestamp.fromDate(DateTime(2026, 7, 1)),
    };

void main() {
  test('반복 필드 없는 구 문서는 repeat none, 빈 excludedDates', () {
    final e = EventModel.fromMap(_baseMap());
    expect(e.repeat, RepeatRule.none);
    expect(e.repeatUntil, isNull);
    expect(e.excludedDates, isEmpty);
  });

  test('알 수 없는 repeat 문자열은 none 취급', () {
    final e = EventModel.fromMap(_baseMap()..['repeat'] = 'biweekly');
    expect(e.repeat, RepeatRule.none);
  });

  test('반복 필드 직렬화 왕복', () {
    final map = _baseMap()
      ..['repeat'] = 'weekly'
      ..['repeatUntil'] = Timestamp.fromDate(DateTime(2026, 12, 31))
      ..['excludedDates'] = [Timestamp.fromDate(DateTime(2026, 7, 13))];
    final e = EventModel.fromMap(map);
    expect(e.repeat, RepeatRule.weekly);
    expect(e.repeatUntil, DateTime(2026, 12, 31));
    expect(e.excludedDates, [DateTime(2026, 7, 13)]);

    final out = e.toMap();
    expect(out['repeat'], 'weekly');
    expect((out['repeatUntil'] as Timestamp).toDate(), DateTime(2026, 12, 31));
    expect((out['excludedDates'] as List).length, 1);
  });

  test('copyWithRepeat는 repeatUntil을 null로 덮어쓸 수 있다', () {
    final e = EventModel.fromMap(_baseMap()
      ..['repeat'] = 'daily'
      ..['repeatUntil'] = Timestamp.fromDate(DateTime(2026, 12, 31)));
    final cleared = e.copyWithRepeat(repeat: RepeatRule.daily, repeatUntil: null);
    expect(cleared.repeatUntil, isNull);
    expect(cleared.repeat, RepeatRule.daily);
    expect(cleared.id, e.id);
  });

  test('copyWithRepeat로 excludedDates 추가', () {
    final e = EventModel.fromMap(_baseMap()..['repeat'] = 'weekly');
    final updated = e.copyWithRepeat(
      repeat: e.repeat,
      repeatUntil: e.repeatUntil,
      excludedDates: [DateTime(2026, 7, 13)],
    );
    expect(updated.excludedDates, [DateTime(2026, 7, 13)]);
  });

  test('기존 copyWith는 반복 필드를 보존한다', () {
    final e = EventModel.fromMap(_baseMap()
      ..['repeat'] = 'monthly'
      ..['excludedDates'] = [Timestamp.fromDate(DateTime(2026, 8, 6))]);
    final copied = e.copyWith(title: '월급날');
    expect(copied.repeat, RepeatRule.monthly);
    expect(copied.excludedDates.length, 1);
  });
}
