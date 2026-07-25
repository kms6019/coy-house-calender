import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coy_house_calender/models/event_model.dart';
import 'package:coy_house_calender/utils/conflict_utils.dart';

EventModel _event({
  String id = 'e1',
  String title = 't',
  required DateTime start,
  DateTime? end,
  bool allDay = false,
  String repeat = 'none',
  DateTime? until,
}) {
  return EventModel.fromMap({
    'id': id,
    'coupleId': 'c1',
    'createdByUid': 'u1',
    'title': title,
    'description': null,
    'startDateTime': Timestamp.fromDate(start),
    'endDateTime': end != null ? Timestamp.fromDate(end) : null,
    'isAllDay': allDay,
    'color': 0xFF42A5F5,
    'hasAlarm': false,
    'alarmMinutesBefore': 30,
    'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
    'updatedAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
    'repeat': repeat,
    'repeatUntil': until != null ? Timestamp.fromDate(until) : null,
    'excludedDates': const [],
  });
}

void main() {
  group('findConflicts', () {
    test('겹치는 이벤트가 없으면 빈 리스트', () {
      final existing = _event(
        id: 'a',
        start: DateTime(2026, 7, 25, 10),
        end: DateTime(2026, 7, 25, 11),
      );
      final candidate = _event(
        id: 'new',
        start: DateTime(2026, 7, 25, 14),
        end: DateTime(2026, 7, 25, 15),
      );

      expect(findConflicts([existing], candidate), isEmpty);
    });

    test('부분 겹침을 잡는다', () {
      final existing = _event(
        id: 'a',
        start: DateTime(2026, 7, 25, 14),
        end: DateTime(2026, 7, 25, 15),
      );
      final candidate = _event(
        id: 'new',
        start: DateTime(2026, 7, 25, 14, 30),
        end: DateTime(2026, 7, 25, 15, 30),
      );

      final out = findConflicts([existing], candidate);
      expect(out.map((e) => e.id), ['a']);
    });

    test('완전 포함되는 이벤트를 잡는다', () {
      final existing = _event(
        id: 'a',
        start: DateTime(2026, 7, 25, 9),
        end: DateTime(2026, 7, 25, 18),
      );
      final candidate = _event(
        id: 'new',
        start: DateTime(2026, 7, 25, 13),
        end: DateTime(2026, 7, 25, 14),
      );

      expect(findConflicts([existing], candidate).map((e) => e.id), ['a']);
    });

    test('경계가 맞닿으면 겹침이 아니다', () {
      final existing = _event(
        id: 'a',
        start: DateTime(2026, 7, 25, 13),
        end: DateTime(2026, 7, 25, 14),
      );
      final candidate = _event(
        id: 'new',
        start: DateTime(2026, 7, 25, 14),
        end: DateTime(2026, 7, 25, 15),
      );

      expect(findConflicts([existing], candidate), isEmpty);
    });

    test('후보가 종일이면 빈 리스트', () {
      final existing = _event(
        id: 'a',
        start: DateTime(2026, 7, 25, 13),
        end: DateTime(2026, 7, 25, 14),
      );
      final candidate = _event(
        id: 'new',
        start: DateTime(2026, 7, 25),
        end: DateTime(2026, 7, 25, 23, 59),
        allDay: true,
      );

      expect(findConflicts([existing], candidate), isEmpty);
    });

    test('기존 종일 이벤트는 충돌 후보에서 제외된다', () {
      final existing = _event(
        id: 'a',
        start: DateTime(2026, 7, 25),
        end: DateTime(2026, 7, 25, 23, 59),
        allDay: true,
      );
      final candidate = _event(
        id: 'new',
        start: DateTime(2026, 7, 25, 13),
        end: DateTime(2026, 7, 25, 14),
      );

      expect(findConflicts([existing], candidate), isEmpty);
    });

    test('같은 id(자기 자신)는 제외된다', () {
      final existing = _event(
        id: 'same',
        start: DateTime(2026, 7, 25, 13),
        end: DateTime(2026, 7, 25, 14),
      );
      final candidate = _event(
        id: 'same',
        start: DateTime(2026, 7, 25, 13, 30),
        end: DateTime(2026, 7, 25, 14, 30),
      );

      expect(findConflicts([existing], candidate), isEmpty);
    });

    test('반복 이벤트의 다른 날 회차와 겹치면 잡는다', () {
      // 매주 월요일 10:00-11:00, 시작일 2026-07-06(월)
      final weekly = _event(
        id: 'w',
        start: DateTime(2026, 7, 6, 10),
        end: DateTime(2026, 7, 6, 11),
        repeat: 'weekly',
      );
      // 3주 뒤 월요일에 겹치는 일정
      final candidate = _event(
        id: 'new',
        start: DateTime(2026, 7, 27, 10, 30),
        end: DateTime(2026, 7, 27, 11, 30),
      );

      expect(findConflicts([weekly], candidate).map((e) => e.id), ['w']);
    });

    test('반복 이벤트가 겹치지 않는 요일이면 빈 리스트', () {
      final weekly = _event(
        id: 'w',
        start: DateTime(2026, 7, 6, 10),
        end: DateTime(2026, 7, 6, 11),
        repeat: 'weekly',
      );
      // 화요일
      final candidate = _event(
        id: 'new',
        start: DateTime(2026, 7, 28, 10, 30),
        end: DateTime(2026, 7, 28, 11, 30),
      );

      expect(findConflicts([weekly], candidate), isEmpty);
    });

    test('endDateTime이 null인 이벤트가 구간 내부에 있으면 잡힌다', () {
      final pointEvent = _event(
        id: 'p',
        start: DateTime(2026, 7, 25, 14, 30),
      );
      final candidate = _event(
        id: 'new',
        start: DateTime(2026, 7, 25, 14),
        end: DateTime(2026, 7, 25, 15),
      );

      expect(findConflicts([pointEvent], candidate).map((e) => e.id), ['p']);
    });

    test('결과는 startDateTime 오름차순으로 정렬된다', () {
      final late = _event(
        id: 'late',
        start: DateTime(2026, 7, 25, 14, 30),
        end: DateTime(2026, 7, 25, 15, 30),
      );
      final early = _event(
        id: 'early',
        start: DateTime(2026, 7, 25, 13, 30),
        end: DateTime(2026, 7, 25, 14, 30),
      );
      final candidate = _event(
        id: 'new',
        start: DateTime(2026, 7, 25, 14),
        end: DateTime(2026, 7, 25, 15),
      );

      final out = findConflicts([late, early], candidate);
      expect(out.map((e) => e.id), ['early', 'late']);
    });
  });
}
