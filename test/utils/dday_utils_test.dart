import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coy_house_calender/models/anniversary_model.dart';
import 'package:coy_house_calender/utils/dday_utils.dart';

AnniversaryModel _ann(String type, DateTime date) => AnniversaryModel(
      id: 'id-$type-${date.toIso8601String()}',
      title: 't',
      date: date,
      type: type == 'annual' ? AnniversaryType.annual : AnniversaryType.countUp,
    );

void main() {
  group('dDayLabel countUp', () {
    test('기준일 당일은 D+1', () {
      expect(dDayLabel(_ann('countUp', DateTime(2026, 1, 1)), DateTime(2026, 1, 1)), 'D+1');
    });
    test('경과일 카운트업', () {
      expect(dDayLabel(_ann('countUp', DateTime(2026, 1, 1)), DateTime(2026, 1, 2)), 'D+2');
      expect(dDayLabel(_ann('countUp', DateTime(2025, 7, 17)), DateTime(2026, 7, 17)), 'D+366');
    });
    test('시각 무시 (자정 기준)', () {
      expect(
        dDayLabel(_ann('countUp', DateTime(2026, 1, 1, 23, 59)), DateTime(2026, 1, 2, 0, 1)),
        'D+2',
      );
    });
  });

  group('dDayLabel annual', () {
    test('도래 전 D-n', () {
      expect(dDayLabel(_ann('annual', DateTime(2000, 8, 1)), DateTime(2026, 7, 17)), 'D-15');
    });
    test('당일 D-Day', () {
      expect(dDayLabel(_ann('annual', DateTime(2000, 7, 17)), DateTime(2026, 7, 17)), 'D-Day');
    });
    test('직후엔 내년 도래일 기준', () {
      expect(dDayLabel(_ann('annual', DateTime(2000, 7, 16)), DateTime(2026, 7, 17)), 'D-364');
    });
    test('2/29 기준일은 평년 2/28 취급', () {
      expect(dDayLabel(_ann('annual', DateTime(2024, 2, 29)), DateTime(2026, 2, 1)), 'D-27');
    });
  });

  group('sortedForDisplay', () {
    test('annual 임박순 먼저, countUp은 기준일 오래된 순으로 뒤에', () {
      final now = DateTime(2026, 7, 17);
      final list = [
        _ann('countUp', DateTime(2025, 1, 1)),
        _ann('annual', DateTime(2000, 12, 25)),
        _ann('annual', DateTime(2000, 8, 1)),
        _ann('countUp', DateTime(2024, 1, 1)),
      ];
      final sorted = sortedForDisplay(list, now);
      expect(sorted[0].date.month, 8); // annual 8/1 (D-15)
      expect(sorted[1].date.month, 12); // annual 12/25
      expect(sorted[2].date.year, 2024); // countUp 오래된 것
      expect(sorted[3].date.year, 2025);
    });
  });

  group('AnniversaryModel 직렬화', () {
    test('toMap → fromMap 왕복', () {
      final a = AnniversaryModel(
        id: 'x1',
        title: '처음 만난 날',
        date: DateTime(2024, 3, 1),
        type: AnniversaryType.countUp,
      );
      final b = AnniversaryModel.fromMap(a.toMap());
      expect(b.id, 'x1');
      expect(b.title, '처음 만난 날');
      expect(b.date, DateTime(2024, 3, 1));
      expect(b.type, AnniversaryType.countUp);
    });
    test('toMap의 date는 Timestamp', () {
      final m = _ann('annual', DateTime(2024, 3, 1)).toMap();
      expect(m['date'], isA<Timestamp>());
      expect(m['type'], 'annual');
    });
  });
}
