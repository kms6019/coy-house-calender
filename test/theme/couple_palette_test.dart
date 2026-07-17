import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coy_house_calender/models/couple_model.dart';
import 'package:coy_house_calender/theme/couple_palette.dart';

CoupleModel _couple() => CoupleModel.fromMap({
      'coupleId': 'c1',
      'ownerUid': 'owner-uid',
      'partnerUid': 'partner-uid',
      'inviteCode': 'ABC123',
      'isLinked': true,
      'ownerColor': 0xFF42A5F5,
      'partnerColor': 0xFFF06292,
      'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
    });

void main() {
  test('팔레트는 12색, 전부 불투명 ARGB', () {
    expect(kCouplePalette.length, 12);
    expect(kCouplePalette.toSet().length, 12); // 중복 없음
    for (final c in kCouplePalette) {
      expect(c >> 24 & 0xFF, 0xFF); // alpha FF
    }
  });

  test('owner는 ownerColor 필드', () {
    expect(myColorField(_couple(), 'owner-uid'), 'ownerColor');
  });

  test('partner는 partnerColor 필드', () {
    expect(myColorField(_couple(), 'partner-uid'), 'partnerColor');
  });
}
