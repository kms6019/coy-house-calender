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
    test('미래 기준일은 시작까지 D-n', () {
      expect(dDayLabel(_ann('countUp', DateTime(2026, 7, 20)), DateTime(2026, 7, 17)), 'D-3');
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
    test('기념일 주인(ownerUid) 왕복, 둘의 기념일은 저장하지 않음', () {
      final mine = AnniversaryModel(
        id: 'b1',
        title: '생일',
        date: DateTime(2026, 4, 22),
        type: AnniversaryType.annual,
        ownerUid: 'u1',
      );
      expect(AnniversaryModel.fromMap(mine.toMap()).ownerUid, 'u1');
      final ours = _ann('annual', DateTime(2024, 3, 1));
      expect(ours.toMap().containsKey('ownerUid'), isFalse);
      expect(AnniversaryModel.fromMap(ours.toMap()).ownerUid, isNull);
    });
    test('toMap의 date는 Timestamp', () {
      final m = _ann('annual', DateTime(2024, 3, 1)).toMap();
      expect(m['date'], isA<Timestamp>());
      expect(m['type'], 'annual');
    });
  });

  group('anniversaryEventsForMonth', () {
    test('annual은 매년 해당 월에 표시', () {
      final list = anniversaryEventsForMonth(
          [_ann('annual', DateTime(2020, 7, 15))], DateTime(2026, 7));
      expect(list.length, 1);
      expect(list.first.startDateTime, DateTime(2026, 7, 15));
      expect(list.first.icon, '🎉');
    });

    test('annual 다른 달은 빈 리스트', () {
      final list = anniversaryEventsForMonth(
          [_ann('annual', DateTime(2020, 7, 15))], DateTime(2026, 8));
      expect(list, isEmpty);
    });

    test('annual 2/29는 평년 2/28', () {
      final list = anniversaryEventsForMonth(
          [_ann('annual', DateTime(2024, 2, 29))], DateTime(2026, 2));
      expect(list.first.startDateTime, DateTime(2026, 2, 28));
    });

    test('한 사람의 기념일은 그 사람 색, 둘의 기념일·모르는 사람은 분홍', () {
      AnniversaryModel owned(String? uid) => AnniversaryModel(
            id: 'o-$uid',
            title: '생일',
            date: DateTime(1990, 7, 15),
            type: AnniversaryType.annual,
            ownerUid: uid,
          );
      final list = anniversaryEventsForMonth(
        [owned('u1'), owned(null), owned('stranger')],
        DateTime(2026, 7),
        ownerColors: {'u1': 0xFF42A5F5},
      );
      expect(list.map((e) => e.color), [0xFF42A5F5, 0xFFE91E63, 0xFFE91E63]);
    });

    test('음력 생일은 그해 양력 날짜에 그 사람 색으로', () {
      final a = AnniversaryModel(
        id: 'l1',
        title: '음력 생일',
        date: DateTime(2026, 2, 17),
        type: AnniversaryType.annual,
        isLunar: true,
        lunarMonth: 1,
        lunarDay: 1,
        ownerUid: 'u2',
      );
      // 2026년 음력 1월 1일(설날) = 양력 2월 17일
      final e = anniversaryEventsForDay(
        [a],
        DateTime(2026, 2, 17),
        ownerColors: {'u2': 0xFFF48FB1},
      ).single;
      expect(e.color, 0xFFF48FB1);
    });

    test('countUp은 원 날짜의 달에만 표시', () {
      final a = _ann('countUp', DateTime(2025, 3, 10));
      expect(anniversaryEventsForMonth([a], DateTime(2025, 3)).length, 1);
      expect(anniversaryEventsForMonth([a], DateTime(2026, 3)), isEmpty);
    });
  });

  group('anniversaryEventsForDay', () {
    test('매년 기념일은 그 날짜에만 나온다', () {
      final a = _ann('annual', DateTime(1995, 10, 24));
      expect(anniversaryEventsForDay([a], DateTime(2026, 10, 24)).length, 1);
      expect(anniversaryEventsForDay([a], DateTime(2026, 10, 23)), isEmpty);
    });

    test('목록에서 기념일로 알아볼 수 있는 id 를 쓴다', () {
      final a = _ann('annual', DateTime(1995, 10, 24));
      final e = anniversaryEventsForDay([a], DateTime(2026, 10, 24)).single;
      expect(e.id.startsWith('anniversary-'), isTrue);
    });
  });
}
