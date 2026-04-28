import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../models/event_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    if (kIsWeb) return;

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: android),
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> scheduleAlarm(EventModel event) async {
    if (kIsWeb || !event.hasAlarm) return;

    final alarmTime = event.startDateTime.subtract(
      Duration(minutes: event.alarmMinutesBefore),
    );
    if (alarmTime.isBefore(DateTime.now())) return;

    await _plugin.zonedSchedule(
      event.id.hashCode.abs(),
      event.title,
      event.alarmMinutesBefore == 0
          ? '일정이 시작되었습니다'
          : '${event.alarmMinutesBefore}분 후 시작',
      tz.TZDateTime.from(alarmTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'coy_calendar_channel',
          '캘린더 알림',
          channelDescription: '일정 알림',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelAlarm(String eventId) async {
    if (kIsWeb) return;
    await _plugin.cancel(eventId.hashCode.abs());
  }

  Future<void> cancelAll() async {
    if (kIsWeb) return;
    await _plugin.cancelAll();
  }
}
