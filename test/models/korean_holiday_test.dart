import 'package:coy_house_calender/models/korean_holiday.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('KoreanHoliday JSON round-trip은 날짜를 자정으로 정규화한다', () {
    final holiday = KoreanHoliday(
      date: DateTime(2026, 8, 15, 13, 30),
      name: '광복절',
    );

    final restored = KoreanHoliday.fromJson(holiday.toJson());

    expect(restored.date, DateTime(2026, 8, 15));
    expect(restored.name, '광복절');
  });

  test('같은 날짜의 공휴일 이름을 모두 합친다', () {
    final grouped = groupKoreanHolidaysByDate([
      KoreanHoliday(date: DateTime(2025, 5, 5), name: '어린이날'),
      KoreanHoliday(date: DateTime(2025, 5, 5), name: '부처님오신날'),
    ]);

    expect(
      koreanHolidayNameForDate(grouped, DateTime(2025, 5, 5, 20)),
      '어린이날 · 부처님오신날',
    );
  });
}
