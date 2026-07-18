import 'package:coy_house_calender/models/event_model.dart';
import 'package:coy_house_calender/utils/import_utils.dart';
import 'package:flutter_test/flutter_test.dart';

EventModel _event({
  String title = '데이트',
  DateTime? start,
  bool isAllDay = false,
}) {
  final now = DateTime(2026, 7, 1);

  return EventModel(
    id: 'event-1',
    coupleId: 'couple-1',
    createdByUid: 'user-1',
    title: title,
    startDateTime: start ?? DateTime(2026, 7, 18, 14, 30),
    isAllDay: isAllDay,
    color: 0xFF42A5F5,
    hasAlarm: false,
    alarmMinutesBefore: 30,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('deviceEventToDraft', () {
    test('maps a timed device event and applies draft defaults', () {
      final start = DateTime(2026, 7, 18, 14, 30);
      final end = DateTime(2026, 7, 18, 15, 45);
      final before = DateTime.now();

      final draft = deviceEventToDraft(
        title: '영화 보기',
        start: start,
        end: end,
        isAllDay: false,
        coupleId: 'couple-1',
        myUid: 'user-1',
        color: 0xFF7E57C2,
      );
      final after = DateTime.now();

      expect(draft.id, isEmpty);
      expect(draft.coupleId, 'couple-1');
      expect(draft.createdByUid, 'user-1');
      expect(draft.title, '영화 보기');
      expect(draft.description, isNull);
      expect(draft.startDateTime, start);
      expect(draft.endDateTime, end);
      expect(draft.isAllDay, isFalse);
      expect(draft.color, 0xFF7E57C2);
      expect(draft.hasAlarm, isFalse);
      expect(draft.alarmMinutesBefore, 30);
      expect(draft.repeat, RepeatRule.none);
      expect(draft.repeatUntil, isNull);
      expect(draft.excludedDates, isEmpty);
      expect(draft.icon, isNull);
      expect(draft.createdAt, draft.updatedAt);
      expect(draft.createdAt.isBefore(before), isFalse);
      expect(draft.createdAt.isAfter(after), isFalse);
    });

    test('maps an all-day event with a null end', () {
      final start = DateTime(2026, 7, 20);

      final draft = deviceEventToDraft(
        title: '기념일',
        start: start,
        isAllDay: true,
        coupleId: 'couple-1',
        myUid: 'user-1',
        color: 0xFFFF7043,
      );

      expect(draft.startDateTime, start);
      expect(draft.endDateTime, isNull);
      expect(draft.isAllDay, isTrue);
      expect(draft.color, 0xFFFF7043);
    });
  });

  group('isDuplicateEvent', () {
    test('returns true for an exactly matching event', () {
      final start = DateTime(2026, 7, 18, 14, 30);

      expect(
        isDuplicateEvent(
          [_event(start: start)],
          title: '데이트',
          start: start,
          isAllDay: false,
        ),
        isTrue,
      );
    });

    test('trims both titles before comparing', () {
      expect(
        isDuplicateEvent(
          [_event(title: '  데이트', start: DateTime(2026, 7, 18, 14, 30))],
          title: '데이트  ',
          start: DateTime(2026, 7, 18, 14, 30),
          isAllDay: false,
        ),
        isTrue,
      );
    });

    test('ignores seconds and smaller units for timed events', () {
      expect(
        isDuplicateEvent(
          [_event(start: DateTime(2026, 7, 18, 14, 30, 1, 100))],
          title: '데이트',
          start: DateTime(2026, 7, 18, 14, 30, 59, 999),
          isAllDay: false,
        ),
        isTrue,
      );
    });

    test('compares only normalized dates for all-day events', () {
      expect(
        isDuplicateEvent(
          [_event(start: DateTime(2026, 7, 18, 23, 59), isAllDay: true)],
          title: '데이트',
          start: DateTime(2026, 7, 18, 1, 15),
          isAllDay: true,
        ),
        isTrue,
      );
    });

    test('returns false when titles differ', () {
      expect(
        isDuplicateEvent(
          [_event(title: '데이트')],
          title: '장보기',
          start: DateTime(2026, 7, 18, 14, 30),
          isAllDay: false,
        ),
        isFalse,
      );
    });

    test('does not match an all-day event with a timed event', () {
      final start = DateTime(2026, 7, 18);

      expect(
        isDuplicateEvent(
          [_event(start: start, isAllDay: true)],
          title: '데이트',
          start: start,
          isAllDay: false,
        ),
        isFalse,
      );
      expect(
        isDuplicateEvent(
          [_event(start: start, isAllDay: false)],
          title: '데이트',
          start: start,
          isAllDay: true,
        ),
        isFalse,
      );
    });
  });
}
