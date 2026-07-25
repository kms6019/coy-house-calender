import '../models/event_model.dart';
import 'event_utils.dart';

/// [candidate]와 시간이 겹치는 기존 이벤트 목록. 시작 시각 오름차순.
///
/// 종일 이벤트는 특정 시간대를 점유하지 않으므로 양쪽 모두 검사에서 제외한다.
/// 반복 이벤트는 후보 날짜 범위로 전개해 회차 단위로 비교한다.
/// 겹침은 열린구간 기준이라 앞 일정 종료와 뒤 일정 시작이 맞닿는 경우는 제외된다.
List<EventModel> findConflicts(
  List<EventModel> events,
  EventModel candidate,
) {
  if (candidate.isAllDay) return const [];

  final candidateStart = candidate.startDateTime;
  final candidateEnd = candidate.endDateTime ?? candidateStart;

  final expanded = expandRecurringForRange(
    events.where((e) => !e.isAllDay && e.id != candidate.id).toList(),
    candidateStart,
    candidateEnd,
  );

  final conflicts = expanded.where((event) {
    final start = event.startDateTime;
    final end = event.endDateTime ?? start;
    return candidateStart.isBefore(end) && start.isBefore(candidateEnd);
  }).toList()
    ..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));

  return conflicts;
}
