import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coy_house_calender/models/event_model.dart';
import 'package:coy_house_calender/models/korean_holiday.dart';
import 'package:coy_house_calender/screens/calendar/month_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

EventModel _event({required String title, required DateTime start}) {
  return EventModel.fromMap({
    'id': title,
    'coupleId': 'c1',
    'createdByUid': 'u1',
    'title': title,
    'startDateTime': Timestamp.fromDate(start),
    'isAllDay': false,
    'color': 0xFF42A5F5,
    'hasAlarm': false,
    'alarmMinutesBefore': 30,
    'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
    'updatedAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
    'repeat': 'none',
    'excludedDates': const [],
  });
}

void main() {
  testWidgets('월간 달력에 공휴일 이름을 표시한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 600,
            child: MonthGrid(
              month: DateTime(2026, 8),
              events: const [],
              holidays: [
                KoreanHoliday(date: DateTime(2026, 8, 15), name: '광복절'),
              ],
              selectedDay: DateTime(2026, 8, 1),
              onDayTap: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('광복절'), findsOneWidget);
  });

  // 2026-08-01은 토요일 → 앞 6칸은 7월 26~31일, 뒤 5칸은 9월 1~5일
  testWidgets('인접 월 날짜를 흐리게 표시하고 탭을 무시한다', (tester) async {
    final tapped = <DateTime>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 600,
            child: MonthGrid(
              month: DateTime(2026, 8),
              events: const [],
              selectedDay: DateTime(2026, 8, 1),
              onDayTap: tapped.add,
            ),
          ),
        ),
      ),
    );

    // 8월 27일 + 7월 27일
    expect(find.text('27'), findsNWidgets(2));
    // 8월 5일 + 9월 5일
    expect(find.text('5'), findsNWidgets(2));

    final inMonth = tester.widget<Text>(find.text('5').first);
    final outside = tester.widget<Text>(find.text('5').last);
    expect(outside.style!.color!.a, lessThan(inMonth.style!.color!.a));

    await tester.tap(find.text('5').last);
    expect(tapped, isEmpty);

    await tester.tap(find.text('5').first);
    expect(tapped, [DateTime(2026, 8, 5)]);
  });

  testWidgets('인접 월 날짜의 일정도 흐리게 표시한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 600,
            child: MonthGrid(
              month: DateTime(2026, 8),
              events: [
                _event(title: '이번달일정', start: DateTime(2026, 8, 12, 10)),
                _event(title: '다음달일정', start: DateTime(2026, 9, 2, 10)),
                _event(title: '지난달일정', start: DateTime(2026, 7, 28, 10)),
              ],
              selectedDay: DateTime(2026, 8, 1),
              onDayTap: (_) {},
            ),
          ),
        ),
      ),
    );

    // 인접 월 일정도 숨기지 않고 렌더링한다
    expect(find.text('이번달일정'), findsOneWidget);
    expect(find.text('다음달일정'), findsOneWidget);
    expect(find.text('지난달일정'), findsOneWidget);

    double opacityOf(String title) => tester
        .widgetList<Opacity>(
          find.ancestor(of: find.text(title), matching: find.byType(Opacity)),
        )
        .map((o) => o.opacity)
        .reduce((a, b) => a * b);

    expect(opacityOf('이번달일정'), 1);
    expect(opacityOf('다음달일정'), lessThan(1));
    expect(opacityOf('지난달일정'), lessThan(1));
  });
}
