import 'package:coy_house_calender/utils/widget_month_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildMonthCells', () {
    final today = DateTime(2026, 7, 18);

    test('항상 42칸을 만든다', () {
      final cells = buildMonthCells(today, const <DateTime>{});

      expect(cells, hasLength(42));
    });

    test('2026년 7월 1일은 index 3에 표시된다', () {
      final cells = buildMonthCells(today, const <DateTime>{});

      expect(cells[3]['d'], '1');
    });

    test('이웃 달 칸은 비어 있고 플래그가 false다', () {
      final cells = buildMonthCells(
        today,
        {DateTime(2026, 6, 28), DateTime(2026, 8, 1)},
      );

      expect(cells[0], {'d': '', 'ev': false, 'today': false, 't': <String>[]});
      expect(cells[34], {'d': '', 'ev': false, 'today': false, 't': <String>[]});
    });

    test('today는 정확히 한 칸에만 표시된다', () {
      final cells = buildMonthCells(today, const <DateTime>{});
      final todayCells = cells.where((cell) => cell['today'] == true);

      expect(todayCells, hasLength(1));
      expect(todayCells.single['d'], '18');
    });

    test('eventDays에 포함된 현재 달 날짜만 ev가 true다', () {
      final cells = buildMonthCells(
        today,
        {
          DateTime(2026, 6, 28),
          DateTime(2026, 7, 5),
          DateTime(2026, 7, 18),
        },
      );
      final eventCells = cells.where((cell) => cell['ev'] == true).toList();

      expect(eventCells.map((cell) => cell['d']).toList(), ['5', '18']);
    });
  });

  test('titlesByDay가 있으면 t에 최대 3개', () {
    final cells = buildMonthCells(
      DateTime(2026, 7, 18),
      {DateTime(2026, 7, 18)},
      titlesByDay: {
        DateTime(2026, 7, 18): ['a', 'b', 'c', 'd'],
      },
    );
    final cell = cells.firstWhere((c) => c['d'] == '18');
    expect(cell['t'], ['a', 'b', 'c']);
  });

  test('titlesByDay 없는 날은 t 빈 리스트', () {
    final cells = buildMonthCells(DateTime(2026, 7, 18), {});
    final cell = cells.firstWhere((c) => c['d'] == '18');
    expect(cell['t'], isEmpty);
  });
}
