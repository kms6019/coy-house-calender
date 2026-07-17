import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../models/event_model.dart';
import '../utils/event_utils.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();

  // Windows는 flutter_local_notifications 스케줄링 미지원 → skip
  bool get _supported => !kIsWeb && !Platform.isWindows && !Platform.isMacOS && !Platform.isLinux;

  Future<void> init() async {
    if (!_supported) return;

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: android),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  void _onNotificationTap(NotificationResponse response) {
    // 알림 탭 시 처리 — 향후 특정 이벤트 화면으로 라우팅 가능
  }

  Future<void> scheduleAlarm(EventModel event) async {
    if (!_supported || !event.hasAlarm) return;

    DateTime? occurrenceStart;
    if (event.repeat == RepeatRule.none) {
      occurrenceStart = event.startDateTime;
    } else {
      // 반복: 다음 회차 1건만 스케줄
      occurrenceStart = nextOccurrence(event, DateTime.now());
      if (occurrenceStart != null &&
          occurrenceStart
              .subtract(Duration(minutes: event.alarmMinutesBefore))
              .isBefore(DateTime.now())) {
        occurrenceStart = nextOccurrence(event, occurrenceStart);
      }
    }
    if (occurrenceStart == null) return;

    final alarmTime = occurrenceStart.subtract(
      Duration(minutes: event.alarmMinutesBefore),
    );
    if (alarmTime.isBefore(DateTime.now())) return;

    final body = event.alarmMinutesBefore == 0
        ? '일정이 시작되었습니다'
        : '${event.alarmMinutesBefore}분 후 시작';

    await _plugin.zonedSchedule(
      event.id.hashCode.abs(),
      event.title,
      body,
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
    if (!_supported) return;
    await _plugin.cancel(eventId.hashCode.abs());
  }

  Future<void> cancelAll() async {
    if (!_supported) return;
    await _plugin.cancelAll();
  }
}
