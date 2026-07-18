import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coy_house_calender/models/event_model.dart';
import 'package:coy_house_calender/utils/search_utils.dart';

EventModel _event({
  String id = 'e1',
  String title = '일정',
  String? description,
  String createdByUid = 'me',
  DateTime? start,
}) {
  return EventModel.fromMap({
    'id': id,
    'coupleId': 'c1',
    'createdByUid': createdByUid,
    'title': title,
    'description': description,
    'startDateTime': Timestamp.fromDate(start ?? DateTime(2026, 7, 1)),
    'endDateTime': null,
    'isAllDay': false,
    'color': 0xFF42A5F5,
    'hasAlarm': false,
    'alarmMinutesBefore': 30,
    'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
    'updatedAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
    'repeat': 'none',
    'repeatUntil': null,
    'excludedDates': const [],
    'icon': null,
  });
}

void main() {
  group('searchEvents', () {
    test('returns an empty list for empty or whitespace-only query', () {
      final events = [_event()];

      expect(
        searchEvents(
          events: events,
          query: '',
          filter: SearchFilter.all,
          myUid: 'me',
        ),
        isEmpty,
      );
      expect(
        searchEvents(
          events: events,
          query: '   ',
          filter: SearchFilter.all,
          myUid: 'me',
        ),
        isEmpty,
      );
    });

    test('matches a title substring', () {
      final matching = _event(id: 'matching', title: '주말 데이트');
      final other = _event(id: 'other', title: '장보기');

      final result = searchEvents(
        events: [matching, other],
        query: '데이트',
        filter: SearchFilter.all,
        myUid: 'me',
      );

      expect(result.map((event) => event.id), ['matching']);
    });

    test('matches a description substring', () {
      final matching = _event(
        id: 'matching',
        title: '약속',
        description: '한강에서 피크닉',
      );
      final other = _event(id: 'other', title: '운동', description: '헬스장');

      final result = searchEvents(
        events: [matching, other],
        query: '피크닉',
        filter: SearchFilter.all,
        myUid: 'me',
      );

      expect(result.map((event) => event.id), ['matching']);
    });

    test('matches without regard to case', () {
      final event = _event(title: 'Cafe date');

      final result = searchEvents(
        events: [event],
        query: 'cafe',
        filter: SearchFilter.all,
        myUid: 'me',
      );

      expect(result, [event]);
    });

    test('applies all, mine, and partner filters', () {
      final mine = _event(id: 'mine', title: '저녁', createdByUid: 'me');
      final partner = _event(
        id: 'partner',
        title: '저녁',
        createdByUid: 'partner',
      );
      final events = [mine, partner];

      expect(
        searchEvents(
          events: events,
          query: '저녁',
          filter: SearchFilter.all,
          myUid: 'me',
        ).map((event) => event.id),
        ['mine', 'partner'],
      );
      expect(
        searchEvents(
          events: events,
          query: '저녁',
          filter: SearchFilter.mine,
          myUid: 'me',
        ).map((event) => event.id),
        ['mine'],
      );
      expect(
        searchEvents(
          events: events,
          query: '저녁',
          filter: SearchFilter.partner,
          myUid: 'me',
        ).map((event) => event.id),
        ['partner'],
      );
    });

    test('sorts matching events by startDateTime descending', () {
      final oldest = _event(
        id: 'oldest',
        title: '데이트',
        start: DateTime(2026, 7, 1),
      );
      final newest = _event(
        id: 'newest',
        title: '데이트',
        start: DateTime(2026, 7, 3),
      );
      final middle = _event(
        id: 'middle',
        title: '데이트',
        start: DateTime(2026, 7, 2),
      );

      final result = searchEvents(
        events: [oldest, newest, middle],
        query: '데이트',
        filter: SearchFilter.all,
        myUid: 'me',
      );

      expect(result.map((event) => event.id), ['newest', 'middle', 'oldest']);
    });

    test('handles a null description safely', () {
      final event = _event(title: '장보기');

      final result = searchEvents(
        events: [event],
        query: '없는 메모',
        filter: SearchFilter.all,
        myUid: 'me',
      );

      expect(result, isEmpty);
    });
  });
}
