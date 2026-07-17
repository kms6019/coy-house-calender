import 'package:flutter/material.dart' show DateUtils;
import '../models/anniversary_model.dart';

/// countUp: 기준일 당일 = D+1 (사귄 날 당일을 1일로 센다)
/// annual: 다음 도래일까지 D-n, 당일 D-Day
String dDayLabel(AnniversaryModel a, DateTime now) {
  final today = DateUtils.dateOnly(now);
  final base = DateUtils.dateOnly(a.date);
  if (a.type == AnniversaryType.countUp) {
    return 'D+${today.difference(base).inDays + 1}';
  }
  final diff = nextAnnualDate(base, today).difference(today).inDays;
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

bool _isLeapYear(int y) => (y % 4 == 0 && y % 100 != 0) || y % 400 == 0;

/// 표시 순서: annual 도래 임박순 → countUp 기준일 오래된 순
List<AnniversaryModel> sortedForDisplay(List<AnniversaryModel> list, DateTime now) {
  final today = DateUtils.dateOnly(now);
  final annuals = list.where((a) => a.type == AnniversaryType.annual).toList()
    ..sort((a, b) => nextAnnualDate(DateUtils.dateOnly(a.date), today)
        .compareTo(nextAnnualDate(DateUtils.dateOnly(b.date), today)));
  final countUps = list.where((a) => a.type == AnniversaryType.countUp).toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  return [...annuals, ...countUps];
}
