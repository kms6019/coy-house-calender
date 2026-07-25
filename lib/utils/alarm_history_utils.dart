import '../models/event_model.dart';
import 'event_utils.dart';

class PastAlarm {
  final EventModel event;
  final DateTime alarmAt;

  const PastAlarm({required this.event, required this.alarmAt});
}

/// [now] 기준 과거 [withinDays]일 이내에 울렸을 일정 알람. 최신순.
///
/// 알람 발화는 기록되지 않으므로 이벤트 데이터에서 역산한다.
/// 알람 시각 = 회차 시작 - alarmMinutesBefore.
List<PastAlarm> pastAlarms(
  List<EventModel> events,
  DateTime now, {
  int withinDays = 30,
}) {
  final cutoff = now.subtract(Duration(days: withinDays));

  final occurrences = expandRecurringForRange(
    events.where((e) => e.hasAlarm).toList(),
    cutoff,
    now,
  );

  final result = <PastAlarm>[];
  for (final occurrence in occurrences) {
    final alarmAt = occurrence.startDateTime.subtract(
      Duration(minutes: occurrence.alarmMinutesBefore),
    );
    if (alarmAt.isAfter(now) || alarmAt.isBefore(cutoff)) continue;
    result.add(PastAlarm(event: occurrence, alarmAt: alarmAt));
  }

  result.sort((a, b) {
    final byTime = b.alarmAt.compareTo(a.alarmAt);
    if (byTime != 0) return byTime;
    return a.event.title.compareTo(b.event.title);
  });
  return result;
}
