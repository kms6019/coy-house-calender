import 'package:flutter_test/flutter_test.dart';
import 'package:coy_house_calender/services/settings_migration.dart';

void main() {
  test('returns migration fields when themeMode key missing', () {
    final fields = SettingsMigrationService.fieldsToWrite(
      {'uid': 'u1', 'coupleId': 'c1'},
      legacyHolidayEnabled: false,
      legacyBriefingEnabled: true,
      legacyBriefingHour: 7,
      legacyBriefingMinute: 15,
    );
    expect(fields, isNotNull);
    expect(fields!['showKoreanHolidays'], false);
    expect(fields['briefingEnabled'], true);
    expect(fields['briefingHour'], 7);
    expect(fields['briefingMinute'], 15);
    expect(fields['themeMode'], 'system');
    expect(fields['themeSeedColor'], isNull);
  });

  test('returns null when themeMode key already present (already migrated)', () {
    final fields = SettingsMigrationService.fieldsToWrite(
      {'uid': 'u1', 'themeMode': 'dark'},
      legacyHolidayEnabled: false,
      legacyBriefingEnabled: false,
      legacyBriefingHour: 8,
      legacyBriefingMinute: 0,
    );
    expect(fields, isNull);
  });
}
