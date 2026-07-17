import 'package:intl/intl.dart';
import '../models/event_model.dart';

class BriefingContent {
  final String title;
  final String body;
  const BriefingContent({required this.title, required this.body});
}

/// 하루 일정 요약. 빈 리스트면 null (브리핑 스킵).
BriefingContent? briefingBody(List<EventModel> dayEvents) {
  if (dayEvents.isEmpty) return null;
  final timeFmt = DateFormat('HH:mm');
  final parts = dayEvents.take(3).map((e) {
    final name =
        e.icon?.isNotEmpty == true ? '${e.icon} ${e.title}' : e.title;
    final time = e.isAllDay ? '종일' : timeFmt.format(e.startDateTime);
    return '$name ($time)';
  }).join(', ');
  final extra =
      dayEvents.length > 3 ? ' 외 ${dayEvents.length - 3}건' : '';
  return BriefingContent(
    title: '오늘의 일정 ${dayEvents.length}건',
    body: '$parts$extra',
  );
}
