import 'package:shared_preferences/shared_preferences.dart';

/// 기기(삼성) 캘린더 동기화 on/off — 기기별 설정.
///
/// 일부 기기에서 CalendarProvider 조회가 "성공 + 빈 목록"을 돌려주고 캘린더
/// 삭제도 먹지 않아, 동기화를 돌릴수록 사본이 쌓이는 사례가 있다. 그럴 때
/// 사용자가 직접 끌 수 있어야 한다.
class DeviceSyncPrefs {
  static const _key = 'device_calendar_sync_enabled';

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs.getBool(_key) ?? true;
  }

  static Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}
