import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart' show isSameDay;
import '../../models/event_model.dart';
import '../../models/korean_holiday.dart';
import '../../theme/design_tokens.dart';
import '../../utils/event_utils.dart';

/// 셀 하나의 높이 (디자인 원본 50px)
const double _cellHeight = 50;
const int _maxMarks = 3;
const int _weekCount = 6;

/// 날짜 숫자 색. 인접 월 → 흐리게, 일요일·공휴일 → 빨강, 토요일 → 파랑.
Color _dayNumberColor(
  DesignTokens t, {
  required int weekdayIndex,
  required bool isOutside,
  required bool isHoliday,
}) {
  if (isOutside) return t.dim;
  if (weekdayIndex == 0 || isHoliday) return t.sunday;
  if (weekdayIndex == 6) return t.saturday;
  return t.ink;
}

/// 월 그리드.
///
/// 기본(접힘): 날짜 숫자 아래에 일정 색 점을 최대 3개 찍는다.
/// [expanded]: 받은 높이를 6주로 나눠 칸마다 일정 제목을 넣는다(삼성캘린더 월 보기).
class MonthGrid extends StatelessWidget {
  final DateTime month;
  final List<EventModel> events;
  final List<KoreanHoliday> holidays;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onDayTap;
  final bool expanded;

  const MonthGrid({
    super.key,
    required this.month,
    required this.events,
    this.holidays = const [],
    required this.selectedDay,
    required this.onDayTap,
    this.expanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final firstOfMonth = DateTime(month.year, month.month, 1);
    final leadingBlanks = firstOfMonth.weekday % 7; // Sunday = 0

    final today = DateUtils.dateOnly(DateTime.now());
    final holidaysByDate = groupKoreanHolidaysByDate(holidays);

    if (expanded) {
      final eventsByDate = _eventsByDate();
      return LayoutBuilder(
        builder: (context, box) {
          final rowHeight = box.maxHeight / _weekCount;
          return Column(
            children: List.generate(_weekCount, (week) {
              return SizedBox(
                height: rowHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: List.generate(7, (col) {
                    final date = DateTime(
                      month.year,
                      month.month,
                      week * 7 + col - leadingBlanks + 1,
                    );
                    final isOutside =
                        date.month != month.month || date.year != month.year;
                    return Expanded(
                      child: _ExpandedDayCell(
                        date: date,
                        weekdayIndex: col,
                        isOutside: isOutside,
                        isSelected: isSameDay(date, selectedDay),
                        isToday: isSameDay(date, today),
                        holidayNames: isOutside
                            ? const []
                            : (holidaysByDate[date] ?? const [])
                                  .map((h) => h.name)
                                  .toList(),
                        events: eventsByDate[date] ?? const [],
                        onTap: () => onDayTap(date),
                      ),
                    );
                  }),
                ),
              );
            }),
          );
        },
      );
    }

    final marksByDate = _marksByDate();

    // 달마다 높이가 흔들리지 않도록 항상 6주(42칸) 고정 — 디자인 원본과 동일
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(_weekCount, (week) {
        return Row(
          children: List.generate(7, (col) {
            // 앞뒤 칸은 인접 월의 실제 날짜로 채운다(흐리게 표시).
            final date = DateTime(
              month.year,
              month.month,
              week * 7 + col - leadingBlanks + 1,
            );
            final isOutside =
                date.month != month.month || date.year != month.year;
            return Expanded(
              child: _DayCell(
                date: date,
                weekdayIndex: col,
                isOutside: isOutside,
                isSelected: isSameDay(date, selectedDay),
                isToday: isSameDay(date, today),
                isHoliday: !isOutside && holidaysByDate.containsKey(date),
                marks: marksByDate[date] ?? const [],
                onTap: () => onDayTap(date),
              ),
            );
          }),
        );
      }),
    );
  }

  /// 날짜별 점 색상. 여러 날 걸친 일정은 걸친 날 전부에 점을 찍는다.
  Map<DateTime, List<Color>> _marksByDate() {
    final result = <DateTime, List<Color>>{};
    final sorted = [...events]..sort(compareCalendarEvents);
    for (final event in sorted) {
      final start = calendarDateKey(event.startDateTime);
      final end = calendarDateKey(event.endDateTime ?? event.startDateTime);
      for (var day = start; !day.isAfter(end); day = day.add(_oneDay)) {
        final marks = result.putIfAbsent(day, () => <Color>[]);
        if (marks.length < _maxMarks) marks.add(event.colorValue);
      }
    }
    return result;
  }

  /// 날짜별 일정 목록(종일 먼저, 시각순). 여러 날 일정은 걸친 날마다 넣는다.
  Map<DateTime, List<EventModel>> _eventsByDate() {
    final result = <DateTime, List<EventModel>>{};
    final sorted = [...events]..sort(compareCalendarEvents);
    for (final event in sorted) {
      final start = calendarDateKey(event.startDateTime);
      final end = calendarDateKey(event.endDateTime ?? event.startDateTime);
      for (var day = start; !day.isAfter(end); day = day.add(_oneDay)) {
        result.putIfAbsent(day, () => <EventModel>[]).add(event);
      }
    }
    return result;
  }

  static const _oneDay = Duration(days: 1);
}

class _DayCell extends StatelessWidget {
  final DateTime date;
  final int weekdayIndex; // 0=Sun .. 6=Sat
  final bool isOutside;
  final bool isSelected;
  final bool isToday;
  final bool isHoliday;
  final List<Color> marks;
  final VoidCallback onTap;

  const _DayCell({
    required this.date,
    required this.weekdayIndex,
    required this.isOutside,
    required this.isSelected,
    required this.isToday,
    required this.isHoliday,
    required this.marks,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = DesignTokens.of(context);

    // 오늘(비선택) → accent, 선택 → 먹색 채움 위 반전
    var numberColor = _dayNumberColor(
      t,
      weekdayIndex: weekdayIndex,
      isOutside: isOutside,
      isHoliday: isHoliday,
    );
    if (isToday && !isSelected && !isOutside) numberColor = t.accent;
    if (isSelected) numberColor = t.pillInk;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: _cellHeight,
        child: Column(
          children: [
            const SizedBox(height: 2),
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? t.pill : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                '${date.day}',
                style: TextStyle(
                  fontSize: 14.5,
                  height: 1,
                  fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                  letterSpacing: -0.29,
                  color: numberColor,
                ),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 5,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final color in marks)
                    Container(
                      width: 4,
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 1.25),
                      decoration: BoxDecoration(
                        color: isOutside ? t.dim : color,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 펼친 월 보기의 한 칸 — 날짜 숫자 + 공휴일 + 일정 제목들.
class _ExpandedDayCell extends StatelessWidget {
  final DateTime date;
  final int weekdayIndex;
  final bool isOutside;
  final bool isSelected;
  final bool isToday;
  final List<String> holidayNames;
  final List<EventModel> events;
  final VoidCallback onTap;

  const _ExpandedDayCell({
    required this.date,
    required this.weekdayIndex,
    required this.isOutside,
    required this.isSelected,
    required this.isToday,
    required this.holidayNames,
    required this.events,
    required this.onTap,
  });

  static const double _lineHeight = 17;

  @override
  Widget build(BuildContext context) {
    final t = DesignTokens.of(context);
    var numberColor = _dayNumberColor(
      t,
      weekdayIndex: weekdayIndex,
      isOutside: isOutside,
      isHoliday: holidayNames.isNotEmpty,
    );
    if (isToday && !isSelected && !isOutside) numberColor = t.accent;
    if (isSelected) numberColor = t.pillInk;

    final lines = <Widget>[
      for (final name in holidayNames)
        _CellLabel(text: name, color: t.sunday, tokens: t),
      for (final event in events)
        _CellEvent(event: event, dim: isOutside, tokens: t),
    ];

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: t.hairline)),
        ),
        padding: const EdgeInsets.fromLTRB(1.5, 3, 1.5, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 22,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? t.pill : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${date.day}',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1,
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                    color: numberColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 3),
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) {
                  final fit = (box.maxHeight / _lineHeight).floor();
                  if (fit <= 0 || lines.isEmpty) return const SizedBox.shrink();
                  if (lines.length <= fit) {
                    return Column(children: lines);
                  }
                  final shown = fit - 1;
                  return Column(
                    children: [
                      ...lines.take(shown),
                      SizedBox(
                        height: _lineHeight,
                        child: Center(
                          child: Text(
                            '+${lines.length - shown}',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: t.ink45,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 공휴일 이름 한 줄.
class _CellLabel extends StatelessWidget {
  final String text;
  final Color color;
  final DesignTokens tokens;
  const _CellLabel({
    required this.text,
    required this.color,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _ExpandedDayCell._lineHeight,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.clip,
        softWrap: false,
        style: TextStyle(
          fontSize: 10.5,
          height: 1.5,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

/// 일정 제목 한 줄. 종일·여러 날 일정은 색 채움, 시각 일정은 왼쪽 색 룰.
class _CellEvent extends StatelessWidget {
  final EventModel event;
  final bool dim;
  final DesignTokens tokens;
  const _CellEvent({
    required this.event,
    required this.dim,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    final color = event.colorValue;
    final title = [
      if (event.icon?.isNotEmpty == true) event.icon!,
      event.title,
    ].join('');
    final filled =
        event.isAllDay ||
        (event.endDateTime != null &&
            !DateUtils.isSameDay(event.startDateTime, event.endDateTime));

    final text = Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.clip,
      softWrap: false,
      style: TextStyle(
        fontSize: 10.5,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: filled
            ? (ThemeData.estimateBrightnessForColor(color) == Brightness.dark
                  ? Colors.white
                  : const Color(0xFF17171A))
            : tokens.ink,
      ),
    );

    return Opacity(
      opacity: dim ? 0.4 : 1,
      child: Container(
        height: _ExpandedDayCell._lineHeight - 1,
        margin: const EdgeInsets.only(bottom: 1),
        padding: EdgeInsets.only(left: filled ? 3 : 0, right: 1),
        alignment: Alignment.centerLeft,
        decoration: filled
            ? BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              )
            : null,
        child: filled
            ? text
            : Row(
                children: [
                  Container(width: 2, color: color),
                  const SizedBox(width: 2),
                  Expanded(child: text),
                ],
              ),
      ),
    );
  }
}
