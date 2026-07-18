import 'package:coy_house_calender/utils/korean_holiday_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('공휴일만 파싱하고 기념일은 제외한다', () {
    const source = '''BEGIN:VCALENDAR
BEGIN:VEVENT
DTSTART;VALUE=DATE:20260815
DESCRIPTION:공휴일
SUMMARY:광복절
END:VEVENT
BEGIN:VEVENT
DTSTART;VALUE=DATE:20260515
DESCRIPTION:기념일\\n기념일을 숨길 수 있습니다.
SUMMARY:스승의날
END:VEVENT
END:VCALENDAR''';

    final holidays = parseKoreanHolidaysIcs(source);

    expect(holidays, hasLength(1));
    expect(holidays.single.date, DateTime(2026, 8, 15));
    expect(holidays.single.name, '광복절');
  });

  test('접힌 줄과 escaped text를 풀고 대체공휴일 이름을 정규화한다', () {
    const source = '''BEGIN:VCALENDAR\r
BEGIN:VEVENT\r
DTSTART;VALUE=DATE:20260302\r
DESCRIPTION:공휴일\\n대한민국의 휴일\r
SUMMARY:쉬는 날 삼\r
 일절\r
END:VEVENT\r
END:VCALENDAR\r
''';

    final holidays = parseKoreanHolidaysIcs(source);

    expect(holidays.single.name, '삼일절 대체공휴일');
  });

  test('같은 날짜와 이름의 중복 VEVENT는 하나만 반환한다', () {
    const event = '''BEGIN:VEVENT
DTSTART;VALUE=DATE:20260101
DESCRIPTION:공휴일
SUMMARY:새해첫날
END:VEVENT
''';

    final holidays = parseKoreanHolidaysIcs('$event$event');

    expect(holidays, hasLength(1));
    expect(holidays.single.name, '신정');
  });
}
