import '../models/event_model.dart';
import 'alarm_history_service.dart';
import 'notification_service.dart';

/// 일정 알람 재예약 + 기록.
///
/// 앱 화면(alarmSyncProvider)과 백그라운드 FCM 핸들러가 공유한다. 상대가 올린 일정은
/// 푸시로만 도착하므로, 앱을 열지 않아도 여기서 알람이 예약돼야 한다.
Future<void> syncAlarms(
  List<EventModel> events,
  String? uid, {
  AlarmHistoryService? history,
}) async {
  final ns = NotificationService();
  final store = history ?? AlarmHistoryService();
  final keepIds = <String>{};

  for (final event in events) {
    await ns.cancelAlarm(event.id);
    final scheduled = await ns.scheduleAlarm(event);
    if (scheduled == null || uid == null) continue;
    keepIds.add(alarmRecordId(event.id, scheduled.alarmAt));
    await store.recordScheduled(
      uid,
      eventId: event.id,
      title: event.title,
      occurrenceStart: scheduled.occurrenceStart,
      alarmAt: scheduled.alarmAt,
    );
  }

  if (uid != null) await store.reconcile(uid, keepIds, DateTime.now());
}
