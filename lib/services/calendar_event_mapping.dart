import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CalendarEventMapping {
  static const _mapKey = 'samsung_calendar_event_map';
  static const _calendarIdKey = 'samsung_calendar_id';

  Future<Map<String, String>> _loadMap() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_mapKey);
    if (raw == null) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, v as String));
  }

  Future<void> _saveMap(Map<String, String> map) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_mapKey, jsonEncode(map));
  }

  Future<Map<String, String>> loadAll() => _loadMap();

  Future<String?> getDeviceEventId(String firestoreEventId) async {
    final map = await _loadMap();
    return map[firestoreEventId];
  }

  Future<void> setDeviceEventId(String firestoreEventId, String deviceEventId) async {
    final map = await _loadMap();
    map[firestoreEventId] = deviceEventId;
    await _saveMap(map);
  }

  Future<void> removeDeviceEventId(String firestoreEventId) async {
    final map = await _loadMap();
    map.remove(firestoreEventId);
    await _saveMap(map);
  }

  Future<String?> getCalendarId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_calendarIdKey);
  }

  Future<void> setCalendarId(String calendarId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_calendarIdKey, calendarId);
  }
}
