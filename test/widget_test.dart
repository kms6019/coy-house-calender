import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coy_house_calender/models/event_model.dart';
import 'package:coy_house_calender/models/korean_holiday.dart';
import 'package:coy_house_calender/screens/calendar/month_grid.dart';
import 'package:coy_house_calender/theme/app_theme.dart';
import 'package:coy_house_calender/theme/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _seed = kPrimaryPurple.toARGB32();
final _tokens = DesignTokens.light(kPrimaryPurple);

EventModel _event({
  required String title,
  required DateTime start,
  DateTime? end,
  int color = 0xFF42A5F5,
}) {
  return EventModel.fromMap({
    'id': title,
    'coupleId': 'c1',
    'createdByUid': 'u1',
    'title': title,
    'startDateTime': Timestamp.fromDate(start),
    'endDateTime': end != null ? Timestamp.fromDate(end) : null,
    'isAllDay': end != null,
    'color': color,
    'hasAlarm': false,
    'alarmMinutesBefore': 30,
    'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
    'updatedAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
    'repeat': 'none',
    'excludedDates': const [],
  });
}

/// 2026-08-01은 토요일 → 앞 6칸은 7월 26~31일, 뒤 5칸은 9월 1~5일
Future<void> _pumpGrid(
  WidgetTester tester, {
  List<EventModel> events = const [],
  List<KoreanHoliday> holidays = const [],
  ValueChanged<DateTime>? onDayTap,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: buildLightTheme(_seed),
      home: Scaffold(
        body: SizedBox(
          width: 420,
          height: 700,
          child: MonthGrid(
            month: DateTime(2026, 8),
            events: events,
            holidays: holidays,
            selectedDay: DateTime(2026, 8, 1),
            onDayTap: onDayTap ?? (_) {},
          ),
        ),
      ),
    ),
  );
}

/// 그리드에 찍힌 점(원형 Container)의 색 목록
List<Color> _dotColors(WidgetTester tester) {
  return tester
      .widgetList<Container>(find.byType(Container))
      .map((c) => c.decoration)
      .whereType<BoxDecoration>()
      .where((d) => d.shape == BoxShape.circle)
      .map((d) => d.color!)
      .toList();
}

Color _numberColor(WidgetTester tester, String day, {bool last = false}) {
  final finder = find.text(day);
  final text = tester.widget<Text>(last ? finder.last : finder.first);
  return text.style!.color!;
}

void main() {
  testWidgets('인접 월 날짜를 흐리게 표시한다', (tester) async {
    await _pumpGrid(tester);

    // 앞줄 7월 27일 + 이번 달 8월 27일
    expect(find.text('27'), findsNWidgets(2));
    expect(_numberColor(tester, '27'), _tokens.dim);
    expect(_numberColor(tester, '27', last: true), _tokens.ink);

    // 8월 5일 + 9월 5일
    expect(_numberColor(tester, '5', last: true), _tokens.dim);
  });

  testWidgets('인접 월 날짜도 탭할 수 있다', (tester) async {
    final tapped = <DateTime>[];
    await _pumpGrid(tester, onDayTap: tapped.add);

    await tester.tap(find.text('5').last); // 9월 5일
    expect(tapped, [DateTime(2026, 9, 5)]);
  });

  testWidgets('일정이 있는 날에 일정 색 점을 찍는다', (tester) async {
    await _pumpGrid(
      tester,
      events: [
        _event(title: '이번달일정', start: DateTime(2026, 8, 12, 10)),
        _event(
          title: '다음달일정',
          start: DateTime(2026, 9, 3, 10),
          color: 0xFF2E7D32,
        ),
      ],
    );

    final dots = _dotColors(tester);
    expect(dots.length, 2);
    // 이번 달 일정은 자기 색, 인접 월 일정은 흐린 색
    expect(dots, contains(const Color(0xFF42A5F5)));
    expect(dots, contains(_tokens.dim));
  });

  testWidgets('여러 날 걸친 일정은 걸친 날마다 점을 찍는다', (tester) async {
    await _pumpGrid(
      tester,
      events: [
        _event(
          title: '여행',
          start: DateTime(2026, 8, 10),
          end: DateTime(2026, 8, 13),
        ),
      ],
    );

    expect(_dotColors(tester).length, 4); // 10, 11, 12, 13
  });

  testWidgets('한 날의 점은 최대 3개까지만 찍는다', (tester) async {
    await _pumpGrid(
      tester,
      events: [
        for (var i = 0; i < 5; i++)
          _event(title: '일정$i', start: DateTime(2026, 8, 12, 9 + i)),
      ],
    );

    expect(_dotColors(tester).length, 3);
  });

  testWidgets('공휴일 날짜 숫자를 일요일 색으로 표시한다', (tester) async {
    await _pumpGrid(
      tester,
      holidays: [KoreanHoliday(date: DateTime(2026, 8, 15), name: '광복절')],
    );

    // 8월 15일은 토요일이지만 공휴일이라 빨간색
    expect(_numberColor(tester, '15'), _tokens.sunday);
    // 공휴일 이름은 그리드가 아니라 아젠다 영역에서 보여준다
    expect(find.text('광복절'), findsNothing);
  });

  testWidgets('일요일은 빨간색, 평일은 기본 잉크색', (tester) async {
    await _pumpGrid(tester);

    expect(_numberColor(tester, '16'), _tokens.sunday); // 8/16 일요일
    expect(_numberColor(tester, '18'), _tokens.ink); // 8/18 화요일
  });
}
