import 'package:coy_house_calender/models/korean_holiday.dart';
import 'package:coy_house_calender/screens/calendar/month_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
