/// 42칸. 각 칸은 날짜/일정/오늘/공휴일 정보를 가진다.
/// 그리드 시작 = today가 속한 달 1일 주의 일요일. 이웃 달 칸은 d=''(ev/today false)
/// t = 그 날 이벤트 제목 (titlesByDay에서, 최대 3개)
List<Map<String, Object>> buildMonthCells(
  DateTime today,
  Set<DateTime> eventDays, {
  Map<DateTime, List<String>> titlesByDay = const {},
  Map<DateTime, String> holidayNamesByDay = const {},
}) {
  final normalizedToday = DateTime(today.year, today.month, today.day);
  final monthStart = DateTime(today.year, today.month);
  final rangeStart = monthStart.subtract(
    Duration(days: monthStart.weekday % DateTime.daysPerWeek),
  );

  return List<Map<String, Object>>.generate(42, (index) {
    final date = rangeStart.add(Duration(days: index));
    final isCurrentMonth = date.month == today.month && date.year == today.year;

    if (!isCurrentMonth) {
      return {
        'd': '',
        'ev': false,
        'today': false,
        'holiday': false,
        'h': '',
        't': const <String>[],
      };
    }

    final holidayName = holidayNamesByDay[date] ?? '';
    return {
      'd': date.day.toString(),
      'ev': eventDays.contains(date),
      'today': date == normalizedToday,
      'holiday': holidayName.isNotEmpty,
      'h': holidayName,
      't': (titlesByDay[date] ?? const <String>[]).take(3).toList(),
    };
  });
}
