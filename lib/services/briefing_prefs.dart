import 'package:shared_preferences/shared_preferences.dart';

/// 아침 브리핑 기기별 설정
class BriefingPrefs {
  final bool enabled;
  final int hour;
  final int minute;
  const BriefingPrefs({
    required this.enabled,
    required this.hour,
    required this.minute,
  });

  static Future<BriefingPrefs> load() async {
    final p = await SharedPreferences.getInstance();
    return BriefingPrefs(
      enabled: p.getBool('briefing_enabled') ?? false,
      hour: p.getInt('briefing_hour') ?? 8,
      minute: p.getInt('briefing_minute') ?? 0,
    );
  }

  static Future<void> save({
    required bool enabled,
    required int hour,
    required int minute,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('briefing_enabled', enabled);
    await p.setInt('briefing_hour', hour);
    await p.setInt('briefing_minute', minute);
  }
}
