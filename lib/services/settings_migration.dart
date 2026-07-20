import 'package:cloud_firestore/cloud_firestore.dart';
import 'holiday_prefs.dart';
import 'briefing_prefs.dart';

/// 구버전(SharedPreferences 전용) 설정을 Firestore users/{uid} 문서로
/// 1회 승격시킨다. themeMode 필드가 이미 있으면 승격 완료로 간주하고 스킵한다.
class SettingsMigrationService {
  final FirebaseFirestore _db;
  SettingsMigrationService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  static Map<String, dynamic>? fieldsToWrite(
    Map<String, dynamic> rawUserDoc, {
    required bool legacyHolidayEnabled,
    required bool legacyBriefingEnabled,
    required int legacyBriefingHour,
    required int legacyBriefingMinute,
  }) {
    if (rawUserDoc.containsKey('themeMode')) return null;
    return {
      'showKoreanHolidays': legacyHolidayEnabled,
      'briefingEnabled': legacyBriefingEnabled,
      'briefingHour': legacyBriefingHour,
      'briefingMinute': legacyBriefingMinute,
      'themeMode': 'system',
      'themeSeedColor': null,
    };
  }

  Future<void> runIfNeeded(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return;
    final briefing = await BriefingPrefs.load();
    final fields = fieldsToWrite(
      doc.data()!,
      legacyHolidayEnabled: await HolidayPrefs.loadEnabled(),
      legacyBriefingEnabled: briefing.enabled,
      legacyBriefingHour: briefing.hour,
      legacyBriefingMinute: briefing.minute,
    );
    if (fields == null) return;
    await _db.collection('users').doc(uid).set(fields, SetOptions(merge: true));
  }
}
