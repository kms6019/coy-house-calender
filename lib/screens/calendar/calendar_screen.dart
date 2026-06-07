import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../providers/calendar_provider.dart';
import '../../models/event_model.dart';
import '../event/event_list_tile.dart';

class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDay = ref.watch(selectedDateProvider);
    final eventsByDate = ref.watch(eventsByDateProvider);
    final selectedEvents = ref.watch(selectedDayEventsProvider);
    final eventsAsync = ref.watch(eventsStreamProvider);
    final coupleAsync = ref.watch(coupleStreamProvider);
    ref.watch(widgetSyncProvider);

    final isToday = isSameDay(selectedDay, DateUtils.dateOnly(DateTime.now()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('CoyHouse Calendar'),
        centerTitle: true,
        actions: [
          // 파트너 연결 상태
          coupleAsync.when(
            data: (couple) => Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(
                couple?.isLinked == true ? Icons.favorite : Icons.favorite_border,
                color: couple?.isLinked == true ? Colors.pink[300] : Colors.grey[400],
                size: 20,
              ),
            ),
            loading: () => const SizedBox.shrink(),
            error: (err, st) => const SizedBox.shrink(),
          ),
          if (eventsAsync.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: eventsAsync.hasError
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                  const SizedBox(height: 8),
                  const Text('일정을 불러오지 못했습니다.'),
                  TextButton(
                    onPressed: () => ref.invalidate(eventsStreamProvider),
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                TableCalendar<EventModel>(
                  locale: 'ko_KR',
                  firstDay: DateTime(2020),
                  lastDay: DateTime(2030),
                  focusedDay: selectedDay,
                  selectedDayPredicate: (day) => isSameDay(day, selectedDay),
                  eventLoader: (day) {
                    final key = DateUtils.dateOnly(day);
                    return eventsByDate[key] ?? [];
                  },
                  onDaySelected: (selected, focused) {
                    ref.read(selectedDateProvider.notifier).state =
                        DateUtils.dateOnly(selected);
                  },
                  calendarStyle: CalendarStyle(
                    todayDecoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    selectedDecoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    markerDecoration: const BoxDecoration(
                      color: Color(0xFFF48FB1),
                      shape: BoxShape.circle,
                    ),
                    markersMaxCount: 3,
                  ),
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                  ),
                ),
                const Divider(height: 1),
                // 선택 날짜 헤더
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                  child: Row(
                    children: [
                      Text(
                        DateFormat('M월 d일 (E)', 'ko_KR').format(selectedDay),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isToday
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      if (isToday) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '오늘',
                            style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // 일정 리스트
                Expanded(
                  child: selectedEvents.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.event_note_outlined,
                                  size: 40, color: Colors.grey[300]),
                              const SizedBox(height: 8),
                              Text('일정이 없습니다',
                                  style: TextStyle(color: Colors.grey[400])),
                              const SizedBox(height: 4),
                              Text('+ 버튼으로 추가해보세요',
                                  style: TextStyle(
                                      color: Colors.grey[300], fontSize: 12)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: selectedEvents.length,
                          itemBuilder: (context, i) =>
                              EventListTile(event: selectedEvents[i]),
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/event/new', extra: selectedDay),
        child: const Icon(Icons.add),
      ),
    );
  }
}
