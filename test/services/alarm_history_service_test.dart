import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coy_house_calender/services/alarm_history_service.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 8, 9, 12);

({String id, DateTime alarmAt}) _entry(String id, DateTime alarmAt) =>
    (id: id, alarmAt: alarmAt);

void main() {
  group('alarmRecordId', () {
    test('같은 이벤트/시각이면 항상 같은 ID (재예약해도 문서가 안 늘어남)', () {
      final at = DateTime(2026, 8, 10, 9);
      expect(alarmRecordId('ev1', at), alarmRecordId('ev1', at));
    });

    test('회차가 다르면 ID도 다르다', () {
      expect(
        alarmRecordId('ev1', DateTime(2026, 8, 10, 9)),
        isNot(alarmRecordId('ev1', DateTime(2026, 8, 17, 9))),
      );
    });
  });

  group('alarmRecordsToDelete', () {
    test('이미 울린 기록은 예약이 사라져도 남는다', () {
      final doomed = alarmRecordsToDelete([
        _entry('past', _now.subtract(const Duration(days: 1))),
      ], const {}, _now);
      expect(doomed, isEmpty);
    });

    test('아직 안 울렸고 예약도 없으면 지운다 (일정 삭제/알람 해제)', () {
      final doomed = alarmRecordsToDelete([
        _entry('gone', _now.add(const Duration(hours: 2))),
      ], const {}, _now);
      expect(doomed, ['gone']);
    });

    test('아직 안 울렸지만 여전히 예약돼 있으면 남긴다', () {
      final doomed = alarmRecordsToDelete([
        _entry('live', _now.add(const Duration(hours: 2))),
      ], {'live'}, _now);
      expect(doomed, isEmpty);
    });

    test('시각이 바뀌면 옛 예약만 지우고 새 예약은 남긴다', () {
      final doomed = alarmRecordsToDelete(
        [
          _entry('ev1_new', _now.add(const Duration(hours: 5))),
          _entry('ev1_old', _now.add(const Duration(hours: 2))),
        ],
        {'ev1_new'},
        _now,
      );
      expect(doomed, ['ev1_old']);
    });

    test('maxEntries를 넘긴 오래된 기록을 지운다', () {
      final entries = List.generate(
        5,
        (i) => _entry('e$i', _now.subtract(Duration(days: i + 1))),
      );
      final doomed = alarmRecordsToDelete(
        entries,
        const {},
        _now,
        maxEntries: 3,
      );
      expect(doomed, ['e3', 'e4']);
    });

    test('삭제된 예약은 남길 개수에 포함되지 않는다', () {
      final doomed = alarmRecordsToDelete(
        [
          _entry('pending_gone', _now.add(const Duration(hours: 1))),
          _entry('fired1', _now.subtract(const Duration(days: 1))),
          _entry('fired2', _now.subtract(const Duration(days: 2))),
        ],
        const {},
        _now,
        maxEntries: 2,
      );
      // 예약 취소분만 지우고, 울린 기록 2건은 정원 안이라 유지
      expect(doomed, ['pending_gone']);
    });

    test('경계: alarmAt이 now와 같으면 울린 것으로 본다', () {
      final doomed = alarmRecordsToDelete([_entry('edge', _now)], const {}, _now);
      expect(doomed, isEmpty);
    });
  });

  group('AlarmRecord.fromDoc', () {
    test('필수 시각이 있으면 파싱한다', () {
      final record = AlarmRecord.fromDoc('id1', {
        'eventId': 'ev1',
        'title': '병원',
        'occurrenceStart': Timestamp.fromDate(DateTime(2026, 8, 10, 9)),
        'alarmAt': Timestamp.fromDate(DateTime(2026, 8, 10, 8, 30)),
      });
      expect(record, isNotNull);
      expect(record!.eventId, 'ev1');
      expect(record.title, '병원');
      expect(record.occurrenceStart, DateTime(2026, 8, 10, 9));
      expect(record.alarmAt, DateTime(2026, 8, 10, 8, 30));
    });

    test('serverTimestamp 미확정 등으로 시각이 없으면 null', () {
      expect(
        AlarmRecord.fromDoc('id1', {'eventId': 'ev1', 'title': 't'}),
        isNull,
      );
    });
  });
}
