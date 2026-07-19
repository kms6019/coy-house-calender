import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../models/event_model.dart';
import '../utils/briefing_utils.dart';
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

    const android = AndroidInitializationSettings('@drawable/ic_notification');
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

  int _briefingId(DateTime day) {
    final ymd =
        '${day.year}${day.month.toString().padLeft(2, '0')}${day.day.toString().padLeft(2, '0')}';
    return 'briefing-$ymd'.hashCode.abs();
  }

  /// 아침 브리핑 재스케줄: 8일치 취소 후 enabled면 오늘부터 7일 등록.
  /// 일정 없는 날·이미 지난 시각은 스킵.
  Future<void> scheduleBriefings({
    required List<EventModel> events,
    required bool enabled,
    required int hour,
    required int minute,
  }) async {
    if (!_supported) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (var i = 0; i < 8; i++) {
      await _plugin.cancel(_briefingId(today.add(Duration(days: i))));
    }
    if (!enabled) return;

    for (var i = 0; i < 7; i++) {
      final day = today.add(Duration(days: i));
      final when = DateTime(day.year, day.month, day.day, hour, minute);
      if (when.isBefore(now)) continue;
      final content = briefingBody(eventsForDay(events, day));
      if (content == null) continue;
      try {
        await _plugin.zonedSchedule(
          _briefingId(day),
          content.title,
          content.body,
          tz.TZDateTime.from(when, tz.local),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'briefing_channel',
              '아침 브리핑',
              channelDescription: '오늘의 일정 요약',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (_) {
        // 권한 없음 등 — 알람과 동일하게 무시
      }
    }
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
