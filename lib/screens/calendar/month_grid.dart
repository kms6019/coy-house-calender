import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart' show isSameDay;
import '../../models/event_model.dart';
import '../../utils/event_utils.dart';

const double _laneHeight = 18;
const double _singleEventHeight = 16;

class MonthGrid extends StatelessWidget {
  final DateTime month;
  final List<EventModel> events;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onDayTap;

  const MonthGrid({
    super.key,
    required this.month,
    required this.events,
    required this.selectedDay,
    required this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    final firstOfMonth = DateTime(month.year, month.month, 1);
    final leadingBlanks = firstOfMonth.weekday % 7; // Sunday = 0
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final totalCells = leadingBlanks + daysInMonth;
    final weekCount = (totalCells / 7).ceil();

    final weeks = <List<DateTime?>>[];
    for (var w = 0; w < weekCount; w++) {
      final week = <DateTime?>[];
      for (var d = 0; d < 7; d++) {
        final cellIndex = w * 7 + d;
        final dayNum = cellIndex - leadingBlanks + 1;
        if (dayNum < 1 || dayNum > daysInMonth) {
          week.add(null);
        } else {
          week.add(DateTime(month.year, month.month, dayNum));
        }
      }
      weeks.add(week);
    }

    final today = DateUtils.dateOnly(DateTime.now());

    return Column(
      children: weeks
          .map((week) => Expanded(
                child: _WeekRow(
                  weekDates: week,
                  events: events,
                  selectedDay: selectedDay,
                  today: today,
                  onDayTap: onDayTap,
                ),
              ))
          .toList(),
    );
  }
}

class _WeekRow extends StatelessWidget {
  final List<DateTime?> weekDates;
  final List<EventModel> events;
  final DateTime selectedDay;
  final DateTime today;
  final ValueChanged<DateTime> onDayTap;

  const _WeekRow({
    required this.weekDates,
    required this.events,
    required this.selectedDay,
    required this.today,
    required this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    // 이 주(week)의 실제 달력 날짜 범위 (빈 칸도 명목상 날짜로 채워 계산)
    final firstNonNull = weekDates.firstWhere((d) => d != null)!;
    final weekStart = firstNonNull.subtract(
        Duration(days: weekDates.indexWhere((d) => d != null)));
    final weekDateKeys =
        List.generate(7, (i) => weekStart.add(Duration(days: i)));

    // 여러 날에 걸친 일정 -> 레인 배정
    final multiDay = events.where(isMultiDayEvent).where((e) {
      final start = calendarDateKey(e.startDateTime);
      final end = calendarDateKey(e.endDateTime ?? e.startDateTime);
      return !(end.isBefore(weekDateKeys.first) ||
          start.isAfter(weekDateKeys.last));
    }).toList()
      ..sort((a, b) {
        final aStart = calendarDateKey(a.startDateTime);
        final bStart = calendarDateKey(b.startDateTime);
        final cmp = aStart.compareTo(bStart);
        if (cmp != 0) return cmp;
        return compareCalendarEvents(a, b);
      });

    final laneEndCol = <int>[]; // 레인별 마지막 사용 컬럼
    final barPlacements = <_BarPlacement>[];
    for (final event in multiDay) {
      final start = calendarDateKey(event.startDateTime);
      final end = calendarDateKey(event.endDateTime ?? event.startDateTime);
      final startCol = start.isBefore(weekDateKeys.first)
          ? 0
          : start.difference(weekDateKeys.first).inDays;
      final endCol = end.isAfter(weekDateKeys.last)
          ? 6
          : end.difference(weekDateKeys.first).inDays;

      var laneIndex = laneEndCol.indexWhere((lastCol) => lastCol < startCol);
      if (laneIndex == -1) {
        laneIndex = laneEndCol.length;
        laneEndCol.add(endCol);
      } else {
        laneEndCol[laneIndex] = endCol;
      }
      barPlacements.add(_BarPlacement(
        event: event,
        startCol: startCol,
        endCol: endCol,
        lane: laneIndex,
      ));
    }
    final laneCount = laneEndCol.length;

    // 하루짜리 일정 -> 날짜별 리스트
    final singleByCol = List.generate(7, (_) => <EventModel>[]);
    for (final event in events.where((e) => !isMultiDayEvent(e))) {
      final day = calendarDateKey(event.startDateTime);
      final col = day.difference(weekDateKeys.first).inDays;
      if (col >= 0 && col < 7) {
        singleByCol[col].add(event);
      }
    }
    for (final list in singleByCol) {
      list.sort(compareCalendarEvents);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final colWidth = constraints.maxWidth / 7;
        final barsAreaHeight = laneCount * _laneHeight;
        final headerHeight = 22.0;
        final remainingHeight =
            (constraints.maxHeight - headerHeight - barsAreaHeight)
                .clamp(0, double.infinity);
        final maxSingleRows = (remainingHeight / _singleEventHeight).floor();

        return Stack(
          children: [
            Row(
              children: List.generate(7, (col) {
                final date = weekDates[col];
                return Expanded(
                  child: _DayCell(
                    date: date,
                    weekdayIndex: col,
                    isSelected: date != null && isSameDay(date, selectedDay),
                    isToday: date != null && isSameDay(date, today),
                    headerHeight: headerHeight,
                    topPadding: barsAreaHeight,
                    events: date == null ? const [] : singleByCol[col],
                    maxVisible: maxSingleRows < 0 ? 0 : maxSingleRows,
                    onTap: date == null ? null : () => onDayTap(date),
                  ),
                );
              }),
            ),
            for (final placement in barPlacements)
              Positioned(
                left: placement.startCol * colWidth + 2,
                top: headerHeight + placement.lane * _laneHeight,
                width:
                    (placement.endCol - placement.startCol + 1) * colWidth - 4,
                height: _laneHeight - 2,
                child: GestureDetector(
                  onTap: () => onDayTap(
                      calendarDateKey(placement.event.startDateTime)),
                  child: Container(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: placement.event.colorValue,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      placement.event.icon != null
                          ? '${placement.event.icon} ${placement.event.title}'
                          : placement.event.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _BarPlacement {
  final EventModel event;
  final int startCol;
  final int endCol;
  final int lane;
  _BarPlacement({
    required this.event,
    required this.startCol,
    required this.endCol,
    required this.lane,
  });
}

class _DayCell extends StatelessWidget {
  final DateTime? date;
  final int weekdayIndex; // 0=Sun .. 6=Sat
  final bool isSelected;
  final bool isToday;
  final double headerHeight;
  final double topPadding;
  final List<EventModel> events;
  final int maxVisible;
  final VoidCallback? onTap;

  const _DayCell({
    required this.date,
    required this.weekdayIndex,
    required this.isSelected,
    required this.isToday,
    required this.headerHeight,
    required this.topPadding,
    required this.events,
    required this.maxVisible,
    required this.onTap,
  });

  Color _numberColor(BuildContext context) {
    if (weekdayIndex == 0) return Colors.red[400]!;
    if (weekdayIndex == 6) return Colors.blue[400]!;
    return Theme.of(context).colorScheme.onSurface;
  }

  @override
  Widget build(BuildContext context) {
    if (date == null) {
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200, width: 0.5),
        ),
      );
    }

    final overflowCount = events.length - maxVisible;
    final visibleEvents = events.take(maxVisible < 0 ? 0 : maxVisible);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200, width: 0.5),
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: 2, left: 2, right: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: headerHeight - 2,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: isToday
                        ? BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                          )
                        : null,
                    child: Text(
                      '${date!.day}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isToday ? Colors.white : _numberColor(context),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: topPadding),
              ...visibleEvents.map((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Row(
                      children: [
                        if (e.icon != null)
                          Padding(
                            padding: const EdgeInsets.only(right: 2),
                            child: Text(e.icon!,
                                style: const TextStyle(fontSize: 8)),
                          )
                        else
                          Container(
                            width: 5,
                            height: 5,
                            margin: const EdgeInsets.only(right: 3),
                            decoration: BoxDecoration(
                              color: e.colorValue,
                              shape: BoxShape.circle,
                            ),
                          ),
                        Expanded(
                          child: Text(
                            e.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 9.5),
                          ),
                        ),
                      ],
                    ),
                  )),
              if (overflowCount > 0)
                Text(
                  '+$overflowCount',
                  style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
