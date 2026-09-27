import 'package:klc/klc.dart' as klc;

/// 음력 → 양력 (한국천문연구원 기준, 1391~2050년).
///
/// 음력 30일이 없는 해(작은달)는 29일로 본다 — 음력 생일을 쇠는 일반적인 방식.
/// 윤달은 다루지 않는다(평달 기준). 범위 밖이면 null.
DateTime? lunarToSolar(int year, int month, int day) {
  for (final d in [day, if (day == 30) 29]) {
    if (klc.setLunarDate(year, month, d, false)) {
      return DateTime.parse(klc.getSolarIsoFormat());
    }
  }
  return null;
}

/// 음력 [month]/[day] 가 양력으로 [from] 당일 이후 처음 돌아오는 날.
///
/// 음력 연말(11~12월)은 양력으로 다음 해 1~2월이 되므로 앞뒤 해까지 본다.
DateTime? nextLunarOccurrence(int month, int day, DateTime from) {
  for (var year = from.year - 1; year <= from.year + 1; year++) {
    final solar = lunarToSolar(year, month, day);
    if (solar != null && !solar.isBefore(from)) return solar;
  }
  return null;
}

/// 음력 [month]/[day] 가 양력 [solarMonth] 달 안에 떨어지는 날 (없으면 null).
DateTime? lunarOccurrenceInMonth(int month, int day, DateTime solarMonth) {
  for (final year in [solarMonth.year - 1, solarMonth.year]) {
    final solar = lunarToSolar(year, month, day);
    if (solar != null &&
        solar.year == solarMonth.year &&
        solar.month == solarMonth.month) {
      return solar;
    }
  }
  return null;
}
