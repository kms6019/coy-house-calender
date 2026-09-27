import 'package:coy_house_calender/models/anniversary_model.dart';
import 'package:coy_house_calender/utils/dday_utils.dart';
import 'package:coy_house_calender/utils/lunar_utils.dart';
import 'package:flutter_test/flutter_test.dart';

AnniversaryModel _lunar(int month, int day) => AnniversaryModel(
  id: 'l1',
  title: '음력 생일',
  date: DateTime(2026, 1, 1),
  type: AnniversaryType.annual,
  isLunar: true,
  lunarMonth: month,
  lunarDay: day,
);

void main() {
  group('lunarToSolar', () {
    test('2026 추석(음 8/15)은 9월 25일', () {
      expect(lunarToSolar(2026, 8, 15), DateTime(2026, 9, 25));
    });

    test('2026 설날(음 1/1)은 2월 17일', () {
      expect(lunarToSolar(2026, 1, 1), DateTime(2026, 2, 17));
    });

    test('30일이 없는 작은달은 29일로 본다', () {
      for (var m = 1; m <= 12; m++) {
        final d30 = lunarToSolar(2026, m, 30);
        final d29 = lunarToSolar(2026, m, 29)!;
        expect(d30, isNotNull);
        // 큰달이면 29일 다음날, 작은달이면 29일과 같은 날
        expect(d30!.difference(d29).inDays, anyOf(0, 1));
      }
    });
  });

  group('음력 기념일', () {
    test('다음 도래일 — 올해 지났으면 내년 음력 날짜', () {
      final a = _lunar(8, 15);
      expect(nextAnnualOccurrence(a, DateTime(2026, 9, 1)), DateTime(2026, 9, 25));
      expect(
        nextAnnualOccurrence(a, DateTime(2026, 9, 26)),
        lunarToSolar(2027, 8, 15),
      );
    });

    test('음력 연말 날짜는 양력 다음 해 초로 넘어간다', () {
      final next = nextLunarOccurrence(12, 20, DateTime(2026, 1, 1))!;
      expect(next, lunarToSolar(2025, 12, 20));
      expect(next.year, 2026);
    });

    test('D-Day 라벨과 달력 칸 표시', () {
      final a = _lunar(8, 15);
      expect(dDayLabel(a, DateTime(2026, 9, 25)), 'D-Day');
      expect(dDayLabel(a, DateTime(2026, 9, 20)), 'D-5');
      final sep = anniversaryEventsForMonth([a], DateTime(2026, 9));
      expect(sep.single.startDateTime, DateTime(2026, 9, 25));
      expect(anniversaryEventsForMonth([a], DateTime(2026, 10)), isEmpty);
    });

    test('저장·복원 왕복, 양력 기념일은 음력 필드를 쓰지 않는다', () {
      final a = AnniversaryModel.fromMap({
        ..._lunar(3, 7).toMap(),
        'date': _lunar(3, 7).toMap()['date'],
      });
      expect(a.isLunar, isTrue);
      expect((a.lunarMonth, a.lunarDay), (3, 7));

      final solar = AnniversaryModel(
        id: 's1',
        title: '양력',
        date: DateTime(2020, 5, 1),
        type: AnniversaryType.annual,
      );
      expect(solar.toMap().containsKey('isLunar'), isFalse);
    });
  });
}
