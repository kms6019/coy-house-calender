import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/event_model.dart';
import '../../theme/design_tokens.dart';
import '../../utils/event_utils.dart';

/// 선택한 날의 일정 목록. 디자인의 아젠다 영역.
///
/// 좌측에 시작/종료 시각, 세로 룰(일정 색), 우측에 제목·부제.
class AgendaList extends StatelessWidget {
  final DateTime day;
  final List<EventModel> events;
  final String? holidayName;

  const AgendaList({
    super.key,
    required this.day,
    required this.events,
    this.holidayName,
  });

  @override
  Widget build(BuildContext context) {
    final t = DesignTokens.of(context);
    final label = DateFormat('M월 d일 EEEE', 'ko_KR').format(day);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 110),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                holidayName == null ? label : '$label · $holidayName',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.99,
                  color: holidayName == null ? t.ink45 : t.sunday,
                ),
              ),
            ),
            if (events.isNotEmpty)
              Text(
                '${events.length}건',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.66,
                  color: t.ink30,
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (events.isEmpty)
          _Empty(tokens: t)
        else
          for (final event in events) _AgendaRow(event: event, tokens: t),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  final DesignTokens tokens;
  const _Empty({required this.tokens});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: tokens.hairline)),
      ),
      child: Column(
        children: [
          Container(width: 22, height: 1, color: tokens.ink18),
          const SizedBox(height: 12),
          Text(
            '비어 있는 하루입니다',
            style: TextStyle(
              fontSize: 12,
              letterSpacing: -0.12,
              color: tokens.ink30,
            ),
          ),
        ],
      ),
    );
  }
}

class _AgendaRow extends StatelessWidget {
  final EventModel event;
  final DesignTokens tokens;
  const _AgendaRow({required this.event, required this.tokens});

  @override
  Widget build(BuildContext context) {
    final timeFmt = DateFormat('HH:mm');
    final end = event.endDateTime;
    final subtitle = [
      if (event.icon?.isNotEmpty == true) event.icon!,
      if (event.description?.trim().isNotEmpty == true)
        event.description!.trim(),
    ].join(' · ');

    return InkWell(
      onTap: () => context.push('/event/detail', extra: event),
      child: Container(
        padding: const EdgeInsets.fromLTRB(0, 12, 8, 12),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: tokens.hairline)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 44,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.isAllDay ? '종일' : timeFmt.format(event.startDateTime),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.26,
                      color: tokens.ink,
                    ),
                  ),
                  if (!event.isAllDay && end != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      timeFmt.format(end),
                      style: TextStyle(fontSize: 11, color: tokens.ink30),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 13),
            Container(
              width: 2,
              height: 36,
              color: event.colorValue,
              margin: const EdgeInsets.only(right: 13),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.5,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.36,
                      color: tokens.ink,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: tokens.ink45),
                    ),
                  ],
                ],
              ),
            ),
            if (event.hasAlarm)
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 2),
                child: Icon(Icons.alarm, size: 13, color: tokens.ink30),
              ),
          ],
        ),
      ),
    );
  }
}

/// 하루 일정 정렬 (종일 → 시작시각)
List<EventModel> agendaEventsForDay(List<EventModel> all, DateTime day) =>
    eventsForDay(all, day);
