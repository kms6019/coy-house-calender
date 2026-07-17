import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coy_house_calender/models/couple_model.dart';

Map<String, dynamic> _baseCoupleMap() => {
      'coupleId': 'c1',
      'ownerUid': 'u1',
      'partnerUid': 'u2',
      'inviteCode': 'ABC123',
      'isLinked': true,
      'ownerColor': 0xFF42A5F5,
      'partnerColor': 0xFFF48FB1,
      'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
    };

void main() {
  test('anniversaries 필드 없으면 빈 리스트', () {
    final c = CoupleModel.fromMap(_baseCoupleMap());
    expect(c.anniversaries, isEmpty);
  });

  test('정상 항목 파싱', () {
    final map = _baseCoupleMap()
      ..['anniversaries'] = [
        {
          'id': 'a1',
          'title': '처음 만난 날',
          'date': Timestamp.fromDate(DateTime(2024, 3, 1)),
          'type': 'countUp',
        },
      ];
    final c = CoupleModel.fromMap(map);
    expect(c.anniversaries.length, 1);
    expect(c.anniversaries.first.title, '처음 만난 날');
  });

  test('불량 항목은 개별 스킵, 나머지는 유지', () {
    final map = _baseCoupleMap()
      ..['anniversaries'] = [
        {'id': 'bad'}, // title/date 없음 → 스킵
        {
          'id': 'a2',
          'title': '생일',
          'date': Timestamp.fromDate(DateTime(2000, 8, 1)),
          'type': 'annual',
        },
      ];
    final c = CoupleModel.fromMap(map);
    expect(c.anniversaries.length, 1);
    expect(c.anniversaries.first.id, 'a2');
  });

  test('toMap에 anniversaries 포함', () {
    final map = _baseCoupleMap()
      ..['anniversaries'] = [
        {
          'id': 'a1',
          'title': 't',
          'date': Timestamp.fromDate(DateTime(2024, 3, 1)),
          'type': 'countUp',
        },
      ];
    final c = CoupleModel.fromMap(map);
    expect((c.toMap()['anniversaries'] as List).length, 1);
  });
}
