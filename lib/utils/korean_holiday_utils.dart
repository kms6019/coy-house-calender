import '../models/korean_holiday.dart';

List<KoreanHoliday> parseKoreanHolidaysIcs(String source) {
  final unfolded = <String>[];
  for (final rawLine in source.replaceAll('\r\n', '\n').split('\n')) {
    if ((rawLine.startsWith(' ') || rawLine.startsWith('\t')) &&
        unfolded.isNotEmpty) {
      unfolded[unfolded.length - 1] += rawLine.substring(1);
    } else {
      unfolded.add(rawLine);
    }
  }

  final holidays = <KoreanHoliday>[];
  var inEvent = false;
  final fields = <String, String>{};

  void finishEvent() {
    final description = _decodeIcsText(fields['DESCRIPTION'] ?? '');
    final category = description.split('\n').first.trim();
    final rawDate = fields['DTSTART'] ?? '';
    final rawName = fields['SUMMARY'] ?? '';
    if (category != '공휴일' || rawDate.length < 8 || rawName.isEmpty) return;

    final dateText = rawDate.substring(0, 8);
    final year = int.tryParse(dateText.substring(0, 4));
    final month = int.tryParse(dateText.substring(4, 6));
    final day = int.tryParse(dateText.substring(6, 8));
    if (year == null || month == null || day == null) return;

    holidays.add(
      KoreanHoliday(
        date: DateTime(year, month, day),
        name: _normalizeHolidayName(_decodeIcsText(rawName)),
      ),
    );
  }

  for (final line in unfolded) {
    if (line == 'BEGIN:VEVENT') {
      inEvent = true;
      fields.clear();
      continue;
    }
    if (line == 'END:VEVENT') {
      if (inEvent) finishEvent();
      inEvent = false;
      fields.clear();
      continue;
    }
    if (!inEvent) continue;

    final colon = line.indexOf(':');
    if (colon <= 0) continue;
    final property = line.substring(0, colon).split(';').first;
    if (property == 'DTSTART' ||
        property == 'SUMMARY' ||
        property == 'DESCRIPTION') {
      fields[property] = line.substring(colon + 1);
    }
  }

  final unique = <String, KoreanHoliday>{};
  for (final holiday in holidays) {
    unique['${holiday.date.toIso8601String()}|${holiday.name}'] = holiday;
  }
  final result = unique.values.toList()
    ..sort((a, b) {
      final dateComparison = a.date.compareTo(b.date);
      return dateComparison != 0 ? dateComparison : a.name.compareTo(b.name);
    });
  return result;
}

String _decodeIcsText(String value) {
  return value
      .replaceAll(r'\N', '\n')
      .replaceAll(r'\n', '\n')
      .replaceAll(r'\,', ',')
      .replaceAll(r'\;', ';')
      .replaceAll(r'\\', r'\');
}

String _normalizeHolidayName(String value) {
  final name = value.trim();
  if (name.startsWith('쉬는 날 ')) {
    return '${name.substring(5).trim()} 대체공휴일';
  }
  return switch (name) {
    '새해첫날' => '신정',
    '크리스마스' => '성탄절',
    _ => name,
  };
}
