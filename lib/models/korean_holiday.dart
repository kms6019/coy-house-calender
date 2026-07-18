class KoreanHoliday {
  final DateTime date;
  final String name;

  KoreanHoliday({required DateTime date, required this.name})
    : date = DateTime(date.year, date.month, date.day);

  factory KoreanHoliday.fromJson(Map<String, dynamic> json) {
    final rawDate = json['date'] as String? ?? '';
    final parsed = DateTime.tryParse(rawDate);
    if (parsed == null) {
      throw const FormatException('Invalid Korean holiday date');
    }
    return KoreanHoliday(date: parsed, name: json['name'] as String? ?? '');
  }

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String().substring(0, 10),
    'name': name,
  };
}

Map<DateTime, List<KoreanHoliday>> groupKoreanHolidaysByDate(
  Iterable<KoreanHoliday> holidays,
) {
  final grouped = <DateTime, List<KoreanHoliday>>{};
  for (final holiday in holidays) {
    (grouped[holiday.date] ??= []).add(holiday);
  }
  return grouped;
}

String? koreanHolidayNameForDate(
  Map<DateTime, List<KoreanHoliday>> holidaysByDate,
  DateTime date,
) {
  final key = DateTime(date.year, date.month, date.day);
  final holidays = holidaysByDate[key];
  if (holidays == null || holidays.isEmpty) return null;
  return holidays.map((holiday) => holiday.name).join(' · ');
}
