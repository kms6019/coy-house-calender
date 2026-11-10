import 'package:flutter/material.dart' show DateUtils;
import '../models/anniversary_model.dart';
import '../models/event_model.dart';
import 'lunar_utils.dart';

/// countUp: 기준일 당일 = D+1 (사귄 날 당일을 1일로 센다).
/// 기준일이 미래면 시작까지 D-n로 표시.
/// annual: 다음 도래일까지 D-n, 당일 D-Day
String dDayLabel(AnniversaryModel a, DateTime now) {
  final today = DateUtils.dateOnly(now);
  final base = DateUtils.dateOnly(a.date);
  if (a.type == AnniversaryType.countUp) {
    if (today.isBefore(base)) {
      return 'D-${base.difference(today).inDays}';
    }
    return 'D+${today.difference(base).inDays + 1}';
  }
  final diff = nextAnnualOccurrence(a, today).difference(today).inDays;
  return diff == 0 ? 'D-Day' : 'D-$diff';
}

/// base의 다음 연간 도래일. 2/29는 평년 2/28 취급.
DateTime nextAnnualDate(DateTime base, DateTime today) {
  DateTime occurrence(int year) {
    if (base.month == 2 && base.day == 29 && !_isLeapYear(year)) {
      return DateTime(year, 2, 28);
    }
    return DateTime(year, base.month, base.day);
  }

  final thisYear = occurrence(today.year);
  return thisYear.isBefore(today) ? occurrence(today.year + 1) : thisYear;
}

/// 매년 기념일의 [today] 당일 이후 다음 도래일. 음력이면 음력으로 센다.
DateTime nextAnnualOccurrence(AnniversaryModel a, DateTime today) {
  final base = DateUtils.dateOnly(a.date);
  if (a.isLunar && a.lunarMonth != null && a.lunarDay != null) {
    final lunar = nextLunarOccurrence(a.lunarMonth!, a.lunarDay!, today);
    if (lunar != null) return lunar;
  }
  return nextAnnualDate(base, today);
}

bool _isLeapYear(int y) => (y % 4 == 0 && y % 100 != 0) || y % 400 == 0;

/// 표시 순서: annual 도래 임박순 → countUp 기준일 오래된 순
List<AnniversaryModel> sortedForDisplay(List<AnniversaryModel> list, DateTime now) {
  final today = DateUtils.dateOnly(now);
  final annuals = list.where((a) => a.type == AnniversaryType.annual).toList()
    ..sort((a, b) => nextAnnualOccurrence(a, today)
        .compareTo(nextAnnualOccurrence(b, today)));
  final countUps = list.where((a) => a.type == AnniversaryType.countUp).toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  return [...annuals, ...countUps];
}

/// 기념일을 해당 월 캘린더 셀에 표시할 가상 이벤트로 변환.
/// annual은 매년 해당 월/일(말일 초과 시 말일), countUp은 원 날짜가 속한 달에만.
/// 한 사람의 기념일은 [ownerColors] 의 그 사람 색, 둘의 기념일은 분홍.
List<EventModel> anniversaryEventsForMonth(
    List<AnniversaryModel> anniversaries, DateTime month,
    {Map<String, int> ownerColors = const {}}) {
  final result = <EventModel>[];
  for (final a in anniversaries) {
    DateTime? day;
    if (a.type == AnniversaryType.annual &&
        a.isLunar &&
        a.lunarMonth != null &&
        a.lunarDay != null) {
      day = lunarOccurrenceInMonth(a.lunarMonth!, a.lunarDay!, month);
    } else if (a.type == AnniversaryType.annual) {
      if (a.date.month == month.month) {
        final lastDay = DateUtils.getDaysInMonth(month.year, month.month);
        day = DateTime(month.year, month.month,
            a.date.day > lastDay ? lastDay : a.date.day);
      }
    } else if (a.date.year == month.year && a.date.month == month.month) {
      day = DateTime(month.year, month.month, a.date.day);
    }
    if (day == null) continue;
    result.add(EventModel(
      id: 'anniversary-${a.id}',
      coupleId: '',
      createdByUid: '',
      title: a.title,
      startDateTime: day,
      isAllDay: true,
      color: ownerColors[a.ownerUid] ?? 0xFFE91E63,
      hasAlarm: false,
      alarmMinutesBefore: 0,
      createdAt: day,
      updatedAt: day,
      icon: '🎉',
    ));
  }
  return result;
}

/// 그날 하루에 해당하는 기념일 가상 이벤트 (선택일 일정 목록용).
List<EventModel> anniversaryEventsForDay(
    List<AnniversaryModel> anniversaries, DateTime day,
    {Map<String, int> ownerColors = const {}}) {
  return anniversaryEventsForMonth(anniversaries, day, ownerColors: ownerColors)
      .where((e) => DateUtils.isSameDay(e.startDateTime, day))
      .toList();
}
