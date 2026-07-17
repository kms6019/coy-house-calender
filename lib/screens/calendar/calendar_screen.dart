import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/event_model.dart';
import '../../providers/calendar_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/event_utils.dart';
import '../event/event_list_tile.dart';
import 'anniversary_chips.dart';
import 'month_grid.dart';

const _purple = kPrimaryPurple;
const _weekdayLabels = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];

class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDay = ref.watch(selectedDateProvider);
    final focusedDay = ref.watch(focusedDateProvider);
    final events = ref.watch(eventsStreamProvider).valueOrNull ?? [];
    final monthStart = DateTime(focusedDay.year, focusedDay.month, 1);
    final monthEnd = DateTime(focusedDay.year, focusedDay.month + 1, 0);
    final expandedEvents = expandRecurringForRange(events, monthStart, monthEnd);
    final eventsAsync = ref.watch(eventsStreamProvider);
    final coupleAsync = ref.watch(coupleStreamProvider);
    ref.watch(widgetSyncProvider);
    ref.watch(alarmSyncProvider);

    void changeMonth(int delta) {
      final next = DateTime(focusedDay.year, focusedDay.month + delta, 1);
      ref.read(focusedDateProvider.notifier).state = next;
    }

    void goToToday() {
      final today = DateUtils.dateOnly(DateTime.now());
      ref.read(focusedDateProvider.notifier).state = DateTime(today.year, today.month, 1);
      ref.read(selectedDateProvider.notifier).state = today;
    }

    void openDay(DateTime day) {
      ref.read(selectedDateProvider.notifier).state = day;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) => _DaySheet(day: day),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: _purple,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
                    child: Row(
                      children: [
                        coupleAsync.when(
                          data: (couple) => Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Icon(
                              couple?.isLinked == true ? Icons.favorite : Icons.favorite_border,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          loading: () => const SizedBox(width: 34),
                          error: (err, st) => const SizedBox(width: 34),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.chevron_left, color: Colors.white),
                          onPressed: () => changeMonth(-1),
                        ),
                        GestureDetector(
                          onTap: goToToday,
                          child: Text(
                            DateFormat('yyyy.MM').format(focusedDay),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right, color: Colors.white),
                          onPressed: () => changeMonth(1),
                        ),
                        const Spacer(),
                        if (eventsAsync.isLoading)
                          const Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(Colors.white),
                              ),
                            ),
                          ),
                        IconButton(
                          icon: const Icon(Icons.checklist, color: Colors.white),
                          onPressed: () => context.push('/wishlist'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.settings_outlined, color: Colors.white),
                          onPressed: () => context.push('/settings'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, color: Colors.white),
                          onPressed: () => context.push('/event/new', extra: selectedDay),
                        ),
                      ],
                    ),
                  ),
                  coupleAsync.maybeWhen(
                    data: (couple) => couple == null
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: AnniversaryChips(
                                anniversaries: couple.anniversaries),
                          ),
                    orElse: () => const SizedBox.shrink(),
                  ),
                  Row(
                    children: List.generate(7, (i) {
                      final color = i == 0
                          ? Colors.red[100]
                          : i == 6
                              ? Colors.blue[100]
                              : Colors.white;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            _weekdayLabels[i],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
            Expanded(
              child: eventsAsync.hasError
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
                  : MonthGrid(
                      month: focusedDay,
                      events: expandedEvents,
                      selectedDay: selectedDay,
                      onDayTap: openDay,
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _purple,
        onPressed: goToToday,
        label: const Text('오늘', style: TextStyle(color: Colors.white)),
        icon: const Icon(Icons.today, color: Colors.white),
      ),
    );
  }
}

class _DaySheet extends ConsumerWidget {
  final DateTime day;

  const _DaySheet({required this.day});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allEvents = ref.watch(eventsStreamProvider).valueOrNull ?? <EventModel>[];
    final events = eventsForDay(allEvents, day);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    DateFormat('M월 d일 (E)', 'ko_KR').format(day),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.push('/event/new', extra: day);
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (events.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Text('일정이 없습니다', style: TextStyle(color: Colors.grey[400])),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: events.length,
                  itemBuilder: (context, i) => EventListTile(event: events[i]),
                ),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
