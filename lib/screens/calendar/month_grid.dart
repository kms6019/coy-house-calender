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

/// 월 그리드. 날짜 숫자 아래에 일정 색 점을 최대 3개 찍는다.
class MonthGrid extends StatelessWidget {
  final DateTime month;
  final List<EventModel> events;
  final List<KoreanHoliday> holidays;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onDayTap;

  const MonthGrid({
    super.key,
    required this.month,
    required this.events,
    this.holidays = const [],
    required this.selectedDay,
    required this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    final firstOfMonth = DateTime(month.year, month.month, 1);
    final leadingBlanks = firstOfMonth.weekday % 7; // Sunday = 0

    final today = DateUtils.dateOnly(DateTime.now());
    final holidaysByDate = groupKoreanHolidaysByDate(holidays);
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

    // 인접 월 → 흐리게. 일요일·공휴일 → 빨강. 오늘(비선택) → accent.
    Color numberColor;
    if (isOutside) {
      numberColor = t.dim;
    } else if (weekdayIndex == 0 || isHoliday) {
      numberColor = t.sunday;
    } else {
      numberColor = t.ink;
    }
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
