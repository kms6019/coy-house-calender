import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart' show isSameDay;
import '../../models/event_model.dart';
import '../../models/korean_holiday.dart';
import '../../utils/event_utils.dart';

const double _laneHeight = 18;
const double _singleEventHeight = 16;

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
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final totalCells = leadingBlanks + daysInMonth;
    final weekCount = (totalCells / 7).ceil();

    // 앞뒤 빈 칸은 인접 월의 실제 날짜로 채운다(흐리게 표시).
    final weeks = <List<DateTime>>[];
    for (var w = 0; w < weekCount; w++) {
      weeks.add(
        List.generate(
          7,
          (d) =>
              DateTime(month.year, month.month, w * 7 + d - leadingBlanks + 1),
        ),
      );
    }

    final today = DateUtils.dateOnly(DateTime.now());
    final holidaysByDate = groupKoreanHolidaysByDate(holidays);

    return Column(
      children: weeks
          .map(
            (week) => Expanded(
              child: _WeekRow(
                month: month,
                weekDates: week,
                events: events,
                holidaysByDate: holidaysByDate,
                selectedDay: selectedDay,
                today: today,
                onDayTap: onDayTap,
              ),
            ),
          )
          .toList(),
    );
  }
}

class _WeekRow extends StatelessWidget {
  final DateTime month;
  final List<DateTime> weekDates;
  final List<EventModel> events;
  final Map<DateTime, List<KoreanHoliday>> holidaysByDate;
  final DateTime selectedDay;
  final DateTime today;
  final ValueChanged<DateTime> onDayTap;

  const _WeekRow({
    required this.month,
    required this.weekDates,
    required this.events,
    required this.holidaysByDate,
    required this.selectedDay,
    required this.today,
    required this.onDayTap,
  });

  bool _isOutsideDay(DateTime date) =>
      date.month != month.month || date.year != month.year;

  /// 막대가 이번 달 칸에 한 칸도 걸치지 않는지
  bool _isBarOutside(_BarPlacement p) {
    for (var col = p.startCol; col <= p.endCol; col++) {
      if (!_isOutsideDay(weekDates[col])) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final weekDateKeys = weekDates;

    // 여러 날에 걸친 일정 -> 레인 배정
    final multiDay =
        events.where(isMultiDayEvent).where((e) {
          final start = calendarDateKey(e.startDateTime);
          final end = calendarDateKey(e.endDateTime ?? e.startDateTime);
          return !(end.isBefore(weekDateKeys.first) ||
              start.isAfter(weekDateKeys.last));
        }).toList()..sort((a, b) {
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
      barPlacements.add(
        _BarPlacement(
          event: event,
          startCol: startCol,
          endCol: endCol,
          lane: laneIndex,
        ),
      );
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
        final hasHoliday = weekDates.any(
          (date) => !_isOutsideDay(date) && holidaysByDate.containsKey(date),
        );
        final headerHeight = hasHoliday ? 34.0 : 22.0;
        final remainingHeight =
            (constraints.maxHeight - headerHeight - barsAreaHeight).clamp(
              0,
              double.infinity,
            );
        final maxSingleRows = (remainingHeight / _singleEventHeight).floor();

        return Stack(
          children: [
            Row(
              children: List.generate(7, (col) {
                final date = weekDates[col];
                final isOutside = _isOutsideDay(date);
                return Expanded(
                  child: _DayCell(
                    date: date,
                    weekdayIndex: col,
                    isOutside: isOutside,
                    isSelected: !isOutside && isSameDay(date, selectedDay),
                    isToday: !isOutside && isSameDay(date, today),
                    holidayName: isOutside
                        ? null
                        : koreanHolidayNameForDate(holidaysByDate, date),
                    headerHeight: headerHeight,
                    topPadding: barsAreaHeight,
                    events: singleByCol[col],
                    maxVisible: maxSingleRows < 0 ? 0 : maxSingleRows,
                    onTap: isOutside ? null : () => onDayTap(date),
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
                // 이번 달 칸에 전혀 걸치지 않는 막대만 흐리게 (걸치는 막대는 이어 보이게)
                child: Opacity(
                  opacity: _isBarOutside(placement) ? 0.35 : 1,
                  child: GestureDetector(
                    onTap: _isBarOutside(placement)
                        ? null
                        : () => onDayTap(
                            calendarDateKey(placement.event.startDateTime),
                          ),
                    child: Container(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: placement.event.colorValue,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        placement.event.icon != null
                            ? '${placement.event.icon} ${placement.event.title}'
                            : placement.event.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        // 대비 상대는 테마 배경이 아니라 막대 자신의 색이다.
                        // surface/onSurface를 쓰면 다크모드에서 뒤집혀 안 보인다.
                        style: TextStyle(
                          color:
                              ThemeData.estimateBrightnessForColor(
                                    placement.event.colorValue,
                                  ) ==
                                  Brightness.dark
                              ? Colors.white
                              : Colors.black87,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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
  final DateTime date;
  final int weekdayIndex; // 0=Sun .. 6=Sat
  final bool isOutside; // 인접 월 날짜 — 흐리게, 탭 불가
  final bool isSelected;
  final bool isToday;
  final String? holidayName;
  final double headerHeight;
  final double topPadding;
  final List<EventModel> events;
  final int maxVisible;
  final VoidCallback? onTap;

  const _DayCell({
    required this.date,
    required this.weekdayIndex,
    required this.isOutside,
    required this.isSelected,
    required this.isToday,
    required this.holidayName,
    required this.headerHeight,
    required this.topPadding,
    required this.events,
    required this.maxVisible,
    required this.onTap,
  });

  Color _numberColor(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final Color base;
    if (holidayName != null || weekdayIndex == 0) {
      base = colors.error;
    } else if (weekdayIndex == 6) {
      base = colors.primary;
    } else {
      base = colors.onSurface;
    }
    return isOutside ? base.withValues(alpha: 0.35) : base;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final overflowCount = events.length - maxVisible;
    final visibleEvents = events.take(maxVisible < 0 ? 0 : maxVisible);

    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected
                ? colors.primary.withValues(alpha: 0.5)
                : colors.outlineVariant.withValues(alpha: 0.48),
            width: isSelected ? 1 : 0.5,
          ),
          color: isSelected
              ? colors.primaryContainer.withValues(alpha: 0.58)
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: 2, left: 2, right: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: headerHeight - 2,
                child: Column(
                  children: [
                    Container(
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
                        '${date.day}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isToday
                              ? colors.onPrimary
                              : _numberColor(context),
                        ),
                      ),
                    ),
                    if (holidayName != null)
                      Expanded(
                        child: Text(
                          holidayName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: colors.error,
                            fontSize: 7.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(height: topPadding),
              ...visibleEvents.map(
                (e) => Opacity(
                  opacity: isOutside ? 0.35 : 1,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Row(
                      children: [
                        if (e.icon != null)
                          Padding(
                            padding: const EdgeInsets.only(right: 2),
                            child: Text(
                              e.icon!,
                              style: const TextStyle(fontSize: 8),
                            ),
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
                            style: TextStyle(
                              color: colors.onSurface,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (overflowCount > 0)
                Text(
                  '+$overflowCount',
                  style: TextStyle(
                    fontSize: 9,
                    color: colors.onSurfaceVariant.withValues(
                      alpha: isOutside ? 0.35 : 1,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
