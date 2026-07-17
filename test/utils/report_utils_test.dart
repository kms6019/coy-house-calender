import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coy_house_calender/models/event_model.dart';
import 'package:coy_house_calender/models/wish_model.dart';
import 'package:coy_house_calender/utils/report_utils.dart';

EventModel _event({
  String id = 'e1',
  DateTime? start,
  String createdByUid = 'me',
  bool isAllDay = false,
  String? icon,
  String repeat = 'none',
  DateTime? until,
}) {
  return EventModel.fromMap({
    'id': id,
    'coupleId': 'c1',
    'createdByUid': createdByUid,
    'title': 't',
    'description': null,
    'startDateTime': Timestamp.fromDate(start ?? DateTime(2026, 7, 1)),
    'endDateTime': null,
    'isAllDay': isAllDay,
    'color': 0xFF42A5F5,
    'hasAlarm': false,
    'alarmMinutesBefore': 30,
    'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
    'updatedAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
    'repeat': repeat,
    'repeatUntil': until != null ? Timestamp.fromDate(until) : null,
    'excludedDates': const [],
    'icon': icon,
  });
}

WishModel _wish({String id = 'w1', bool done = false}) {
  return WishModel.fromMap({
    'id': id,
    'coupleId': 'c1',
    'createdByUid': 'me',
    'title': 'wish',
    'memo': null,
    'done': done,
    'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
  });
}

void main() {
  group('buildMonthlyReport', () {
    test('returns zero values for empty input', () {
      final report = buildMonthlyReport(
        events: const [],
        wishes: const [],
        month: DateTime(2026, 7, 18),
        myUid: 'me',
      );

      expect(report.totalEvents, 0);
      expect(report.myEvents, 0);
      expect(report.partnerEvents, 0);
      expect(report.allDayEvents, 0);
      expect(report.topIcon, isNull);
      expect(report.wishesDone, 0);
      expect(report.wishesTotal, 0);
    });

    test('counts only events starting in the requested month', () {
      final report = buildMonthlyReport(
        events: [
          _event(id: 'prev', start: DateTime(2026, 6, 30, 23)),
          _event(id: 'in', start: DateTime(2026, 7, 1)),
          _event(id: 'next', start: DateTime(2026, 8, 1)),
        ],
        wishes: const [],
        month: DateTime(2026, 7, 18),
        myUid: 'me',
      );

      expect(report.totalEvents, 1);
    });

    test('counts weekly recurring occurrences in the month', () {
      final report = buildMonthlyReport(
        events: [_event(start: DateTime(2026, 7, 6, 20), repeat: 'weekly')],
        wishes: const [],
        month: DateTime(2026, 7),
        myUid: 'me',
      );

      expect(report.totalEvents, 4);
      expect(report.myEvents, 4);
    });

    test('classifies my and partner events and counts all-day events', () {
      final report = buildMonthlyReport(
        events: [
          _event(id: 'mine1', createdByUid: 'me'),
          _event(id: 'mine2', createdByUid: 'me', isAllDay: true),
          _event(id: 'partner', createdByUid: 'partner', isAllDay: true),
        ],
        wishes: const [],
        month: DateTime(2026, 7),
        myUid: 'me',
      );

      expect(report.totalEvents, 3);
      expect(report.myEvents, 2);
      expect(report.partnerEvents, 1);
      expect(report.allDayEvents, 2);
    });

    test('returns the most frequent icon and keeps first icon on ties', () {
      final frequent = buildMonthlyReport(
        events: [
          _event(id: 'heart1', icon: 'heart'),
          _event(id: 'star1', icon: 'star'),
          _event(id: 'heart2', icon: 'heart'),
          _event(id: 'empty', icon: ''),
          _event(id: 'none'),
        ],
        wishes: const [],
        month: DateTime(2026, 7),
        myUid: 'me',
      );

      expect(frequent.topIcon, 'heart');

      final tied = buildMonthlyReport(
        events: [
          _event(id: 'first', icon: 'star'),
          _event(id: 'second', icon: 'heart'),
        ],
        wishes: const [],
        month: DateTime(2026, 7),
        myUid: 'me',
      );

      expect(tied.topIcon, 'star');
    });

    test('returns null topIcon when no counted event has an icon', () {
      final report = buildMonthlyReport(
        events: [
          _event(id: 'empty', icon: ''),
          _event(id: 'none'),
        ],
        wishes: const [],
        month: DateTime(2026, 7),
        myUid: 'me',
      );

      expect(report.topIcon, isNull);
    });

    test('counts done and total wishes independent of month', () {
      final report = buildMonthlyReport(
        events: const [],
        wishes: [
          _wish(id: 'done1', done: true),
          _wish(id: 'open', done: false),
          _wish(id: 'done2', done: true),
        ],
        month: DateTime(2026, 7),
        myUid: 'me',
      );

      expect(report.wishesDone, 2);
      expect(report.wishesTotal, 3);
    });
  });
}
