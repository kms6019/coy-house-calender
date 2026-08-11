import 'package:coy_house_calender/services/device_calendar_event_builder.dart';
import 'package:coy_house_calender/services/samsung_calendar_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

DeviceEventRef _e(String id, {String? marker, String key = ''}) =>
    (id: id, marker: marker, key: key);

void main() {
  group('마커', () {
    test('앱이 심은 url 에서 Firestore id 를 뽑는다', () {
      expect(firestoreIdFromMarker(coyEventMarker('ev1')), 'ev1');
    });

    test('앱이 심지 않은 url 은 null', () {
      expect(firestoreIdFromMarker('https://example.com'), isNull);
      expect(firestoreIdFromMarker(null), isNull);
      expect(firestoreIdFromMarker('coyhouse://event/'), isNull);
    });
  });

  group('deviceEventKey', () {
    test('제목 앞뒤 공백은 무시한다', () {
      expect(
        deviceEventKey('  회식 ', DateTime(2026, 8, 12, 19)),
        deviceEventKey('회식', DateTime(2026, 8, 12, 19)),
      );
    });

    test('시작시각이 다르면 다른 키', () {
      expect(
        deviceEventKey('회식', DateTime(2026, 8, 12, 19)),
        isNot(deviceEventKey('회식', DateTime(2026, 8, 12, 20))),
      );
    });
  });

  group('duplicateDeviceEventIdsToDelete', () {
    test('중복이 없으면 아무것도 지우지 않는다', () {
      final doomed = duplicateDeviceEventIdsToDelete([
        _e('1', marker: 'A'),
        _e('2', marker: 'B'),
      ], {'1', '2'});
      expect(doomed, isEmpty);
    });

    test('같은 마커의 사본은 하나만 남긴다', () {
      final doomed = duplicateDeviceEventIdsToDelete([
        _e('1', marker: 'A'),
        _e('2', marker: 'A'),
        _e('3', marker: 'A'),
      ], const {});
      expect(doomed, ['2', '3']);
    });

    test('매핑에 등록된 id 를 우선 남긴다', () {
      final doomed = duplicateDeviceEventIdsToDelete([
        _e('1', marker: 'A'),
        _e('2', marker: 'A'),
        _e('3', marker: 'A'),
      ], {'3'});
      expect(doomed, ['1', '2']);
    });

    test('64개 사본을 1개로 줄인다', () {
      final events = List.generate(64, (i) => _e('id$i', marker: 'A'));
      final doomed = duplicateDeviceEventIdsToDelete(events, {'id40'});
      expect(doomed.length, 63);
      expect(doomed, isNot(contains('id40')));
    });

    // Codex 교차검증에서 지적된 함정들
    test('마커가 없고 앱 일정 지문과도 안 맞으면 건드리지 않는다', () {
      // 사용자가 삼성캘린더에서 직접 만든 일정 2건이 우연히 같은 지문이어도 유지
      final doomed = duplicateDeviceEventIdsToDelete([
        _e('1', key: '내가만든일정|100'),
        _e('2', key: '내가만든일정|100'),
      ], const {});
      expect(doomed, isEmpty);
    });

    test('마커가 없어도 앱 일정 지문과 맞으면 정리한다 (구버전 마이그레이션)', () {
      final doomed = duplicateDeviceEventIdsToDelete(
        [_e('1', key: '출근|100'), _e('2', key: '출근|100')],
        const {},
        knownKeys: {'출근|100'},
      );
      expect(doomed, ['2']);
    });

    test('반복 일정의 여러 회차(같은 id)를 중복으로 오판하지 않는다', () {
      final doomed = duplicateDeviceEventIdsToDelete([
        _e('r1', marker: 'A', key: '요가|100'),
        _e('r1', marker: 'A', key: '요가|200'),
        _e('r1', marker: 'A', key: '요가|300'),
      ], {'r1'});
      expect(doomed, isEmpty);
    });

    test('마커가 다르면 제목·시각이 같아도 별개로 본다', () {
      final doomed = duplicateDeviceEventIdsToDelete([
        _e('1', marker: 'A', key: '출근|100'),
        _e('2', marker: 'B', key: '출근|100'),
      ], const {});
      expect(doomed, isEmpty);
    });
  });
}
