import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coy_house_calender/models/event_model.dart';
import 'package:coy_house_calender/models/event_place.dart';

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
    final e = EventModel.fromMap(_baseMap()..['repeat'] = 'hourly');
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

  group('isShared 필드', () {
    test('필드 없는 구 문서는 false', () {
      expect(EventModel.fromMap(_baseMap()).isShared, isFalse);
    });

    test('직렬화 왕복', () {
      final e = EventModel.fromMap(_baseMap()..['isShared'] = true);
      final out = e.toMap();
      expect(out['isShared'], isTrue);
      expect(EventModel.fromMap(out).isShared, isTrue);
    });

    test('copyWith로 true 반영', () {
      final e = EventModel.fromMap(_baseMap());
      expect(e.copyWith(isShared: true).isShared, isTrue);
    });

    test('copyWith 미지정 시 보존', () {
      final e = EventModel.fromMap(_baseMap()..['isShared'] = true);
      expect(e.copyWith(title: 'x').isShared, isTrue);
    });
  });

  group('status 필드', () {
    test('필드 없는 구 문서는 confirmed', () {
      expect(EventModel.fromMap(_baseMap()).status, 'confirmed');
    });

    test('proposed 직렬화 왕복', () {
      final e = EventModel.fromMap(_baseMap()..['status'] = 'proposed');
      final out = e.toMap();
      expect(out['status'], 'proposed');
      expect(EventModel.fromMap(out).status, 'proposed');
    });

    test('copyWith로 confirmed 반영', () {
      final e = EventModel.fromMap(_baseMap()..['status'] = 'proposed');
      expect(e.copyWith(status: 'confirmed').status, 'confirmed');
    });

    test('copyWith 미지정 시 보존', () {
      final e = EventModel.fromMap(_baseMap()..['status'] = 'proposed');
      expect(e.copyWith(title: 'x').status, 'proposed');
    });

    test('isProposed getter', () {
      final proposed = EventModel.fromMap(_baseMap()..['status'] = 'proposed');
      expect(proposed.isProposed, isTrue);
      expect(EventModel.fromMap(_baseMap()).isProposed, isFalse);
    });
  });

  group('icon 필드', () {
    test('필드 없는 구 문서는 null', () {
      expect(EventModel.fromMap(_baseMap()).icon, isNull);
    });

    test('직렬화 왕복', () {
      final e = EventModel.fromMap(_baseMap()..['icon'] = '🎂');
      expect(e.icon, '🎂');
      expect(e.toMap()['icon'], '🎂');
    });

    test('copyWith는 icon 보존', () {
      final e = EventModel.fromMap(_baseMap()..['icon'] = '🎂');
      expect(e.copyWith(title: 'x').icon, '🎂');
    });

    test('copyWithIcon은 null로 해제 가능', () {
      final e = EventModel.fromMap(_baseMap()..['icon'] = '🎂');
      expect(e.copyWithIcon(null).icon, isNull);
      expect(e.copyWithIcon('⭐').icon, '⭐');
      expect(e.copyWithIcon('⭐').title, e.title);
    });
  });

  group('후기 필드', () {
    test('필드 없는 구 문서는 null', () {
      final e = EventModel.fromMap(_baseMap());
      expect(e.reviewText, isNull);
      expect(e.reviewPhotoUrl, isNull);
    });

    test('직렬화 왕복', () {
      final e = EventModel.fromMap(_baseMap()
        ..['reviewText'] = '함께여서 즐거웠다'
        ..['reviewPhotoUrl'] = 'https://example.com/review.jpg');
      final out = e.toMap();

      expect(out['reviewText'], '함께여서 즐거웠다');
      expect(out['reviewPhotoUrl'], 'https://example.com/review.jpg');
      expect(EventModel.fromMap(out).reviewText, '함께여서 즐거웠다');
      expect(
        EventModel.fromMap(out).reviewPhotoUrl,
        'https://example.com/review.jpg',
      );
    });

    test('copyWith로 반영', () {
      final e = EventModel.fromMap(_baseMap());
      final copied = e.copyWith(
        reviewText: '좋은 하루',
        reviewPhotoUrl: 'https://example.com/photo.jpg',
      );

      expect(copied.reviewText, '좋은 하루');
      expect(copied.reviewPhotoUrl, 'https://example.com/photo.jpg');
    });

    test('copyWith 미지정 시 보존', () {
      final e = EventModel.fromMap(_baseMap()
        ..['reviewText'] = '기억할 하루'
        ..['reviewPhotoUrl'] = 'https://example.com/kept.jpg');
      final copied = e.copyWith(title: '수정된 제목');

      expect(copied.reviewText, '기억할 하루');
      expect(copied.reviewPhotoUrl, 'https://example.com/kept.jpg');
    });
  });

  group('장소 필드', () {
    const placeMap = {
      'name': '스타벅스 강남역점',
      'address': '서울특별시 강남구 강남대로 390',
      'placeId': 'ChIJ123',
    };

    test('구 문서(장소 없음)는 null, toMap 은 place: null', () {
      final e = EventModel.fromMap(_baseMap());
      expect(e.place, isNull);
      expect(e.toMap()['place'], isNull);
    });

    test('직렬화 왕복', () {
      final e = EventModel.fromMap(_baseMap()..['place'] = placeMap);
      expect(e.place!.name, '스타벅스 강남역점');
      expect(e.place!.address, '서울특별시 강남구 강남대로 390');
      expect(e.place!.placeId, 'ChIJ123');
      expect(e.toMap()['place'], placeMap);
    });

    test('이름이 비었거나 형식이 다르면 null', () {
      expect(EventModel.fromMap(_baseMap()..['place'] = {'name': '  '}).place,
          isNull);
      expect(EventModel.fromMap(_baseMap()..['place'] = '집').place, isNull);
    });

    test('copyWith 는 장소를 보존하고 copyWithPlace 는 지울 수 있다', () {
      final e = EventModel.fromMap(_baseMap()..['place'] = placeMap);
      expect(e.copyWith(title: '수정').place!.name, '스타벅스 강남역점');
      expect(e.copyWithIcon('🎉').place, isNotNull);
      expect(e.copyWithPlace(null).place, isNull);
    });

    test('label: 주소가 있으면 "이름, 주소", 없으면 이름만', () {
      expect(EventPlace.fromMap(placeMap)!.label,
          '스타벅스 강남역점, 서울특별시 강남구 강남대로 390');
      expect(const EventPlace(name: '집').label, '집');
    });

    test('mapsUri 는 place id 가 있으면 함께 넘긴다', () {
      final uri = EventPlace.fromMap(placeMap)!.mapsUri;
      expect(uri.host, 'www.google.com');
      expect(uri.queryParameters['api'], '1');
      expect(uri.queryParameters['query'],
          '스타벅스 강남역점, 서울특별시 강남구 강남대로 390');
      expect(uri.queryParameters['query_place_id'], 'ChIJ123');
      expect(const EventPlace(name: '집').mapsUri.queryParameters,
          isNot(contains('query_place_id')));
    });
  });

  test('asNew 는 id·시각만 바꾸고 반복·아이콘·같이·제안·장소를 유지한다', () {
    final e = EventModel.fromMap(_baseMap()
      ..['repeat'] = 'biweekly'
      ..['icon'] = '🎉'
      ..['isShared'] = true
      ..['status'] = 'proposed'
      ..['place'] = {'name': '집'});
    final now = DateTime(2026, 11, 3, 9);
    final created = e.asNew(id: 'new-id', now: now);

    expect(created.id, 'new-id');
    expect(created.createdAt, now);
    expect(created.updatedAt, now);
    expect(created.repeat, RepeatRule.biweekly);
    expect(created.icon, '🎉');
    expect(created.isShared, isTrue);
    expect(created.status, 'proposed');
    expect(created.place!.name, '집');
  });
}
