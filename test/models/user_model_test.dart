import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coy_house_calender/models/user_model.dart';

void main() {
  test('fromMap defaults new settings fields when missing', () {
    final user = UserModel.fromMap({
      'uid': 'u1',
      'email': 'a@b.com',
      'displayName': '철수',
      'coupleId': 'c1',
      'fcmToken': 'token',
      'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
    });
    expect(user.showKoreanHolidays, true);
    expect(user.briefingEnabled, false);
    expect(user.briefingHour, 8);
    expect(user.briefingMinute, 0);
    expect(user.themeMode, 'system');
    expect(user.themeSeedColor, isNull);
  });

  test('toMap/fromMap round trip preserves settings fields', () {
    final user = UserModel(
      uid: 'u1',
      email: 'a@b.com',
      displayName: '철수',
      coupleId: 'c1',
      fcmToken: 'token',
      createdAt: DateTime(2026, 1, 1),
      showKoreanHolidays: false,
      briefingEnabled: true,
      briefingHour: 7,
      briefingMinute: 30,
      themeMode: 'dark',
      themeSeedColor: 0xFF7E57C2,
    );
    final restored = UserModel.fromMap(user.toMap());
    expect(restored.showKoreanHolidays, false);
    expect(restored.briefingEnabled, true);
    expect(restored.briefingHour, 7);
    expect(restored.briefingMinute, 30);
    expect(restored.themeMode, 'dark');
    expect(restored.themeSeedColor, 0xFF7E57C2);
  });

  test('copyWith overrides settings fields independently', () {
    final user = UserModel(
      uid: 'u1',
      email: 'a@b.com',
      displayName: '철수',
      coupleId: 'c1',
      fcmToken: 'token',
      createdAt: DateTime(2026, 1, 1),
    );
    final updated = user.copyWith(themeMode: 'light', briefingHour: 9);
    expect(updated.themeMode, 'light');
    expect(updated.briefingHour, 9);
    expect(updated.showKoreanHolidays, true); // 나머진 기존값 유지
  });
}
