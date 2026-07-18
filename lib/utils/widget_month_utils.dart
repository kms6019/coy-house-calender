/// 42칸. 각 칸 {'d': '15'|'', 'ev': bool, 'today': bool}
/// 그리드 시작 = today가 속한 달 1일 주의 일요일. 이웃 달 칸은 d=''(ev/today false)
List<Map<String, Object>> buildMonthCells(
  DateTime today,
  Set<DateTime> eventDays,
) {
  final normalizedToday = DateTime(today.year, today.month, today.day);
  final monthStart = DateTime(today.year, today.month);
  final rangeStart = monthStart.subtract(
    Duration(days: monthStart.weekday % DateTime.daysPerWeek),
  );

  return List<Map<String, Object>>.generate(42, (index) {
    final date = rangeStart.add(Duration(days: index));
    final isCurrentMonth = date.month == today.month && date.year == today.year;

    if (!isCurrentMonth) {
      return {'d': '', 'ev': false, 'today': false};
    }

    return {
      'd': date.day.toString(),
      'ev': eventDays.contains(date),
      'today': date == normalizedToday,
    };
  });
}
