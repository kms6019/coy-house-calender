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
  final alarmed = events.where((e) => e.hasAlarm).toList();

  // 알람이 일정보다 한참 앞서면 회차 시작은 아직 미래여도 알람은 이미 울렸다.
  // 그런 회차까지 전개되도록 범위 끝을 최대 알람 간격만큼 늘린다.
  final maxAlarmMinutes = alarmed.fold<int>(
    0,
    (max, e) => e.alarmMinutesBefore > max ? e.alarmMinutesBefore : max,
  );

  final occurrences = expandRecurringForRange(
    alarmed,
    cutoff,
    now.add(Duration(minutes: maxAlarmMinutes)),
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
