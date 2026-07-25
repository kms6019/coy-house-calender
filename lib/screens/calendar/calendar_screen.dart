import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/event_model.dart';
import '../../models/korean_holiday.dart';
import '../../providers/calendar_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/dday_utils.dart';
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
    final eventsAsync = ref.watch(eventsStreamProvider);
    final coupleAsync = ref.watch(coupleStreamProvider);
    ref.watch(widgetSyncProvider);
    ref.watch(alarmSyncProvider);
    ref.watch(deviceCalendarSyncProvider);
    ref.watch(settingsMigrationProvider);

    void changeMonth(int delta) {
      final next = DateTime(focusedDay.year, focusedDay.month + delta, 1);
      ref.read(focusedDateProvider.notifier).state = next;
    }

    void goToToday() {
      final today = DateUtils.dateOnly(DateTime.now());
      ref.read(focusedDateProvider.notifier).state = DateTime(
        today.year,
        today.month,
        1,
      );
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
                              couple?.isLinked == true
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          loading: () => const SizedBox(width: 34),
                          error: (err, st) => const SizedBox(width: 34),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(
                            Icons.chevron_left,
                            color: Colors.white,
                          ),
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
                          icon: const Icon(
                            Icons.chevron_right,
                            color: Colors.white,
                          ),
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
                                valueColor: AlwaysStoppedAnimation(
                                  Colors.white,
                                ),
                              ),
                            ),
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
                              anniversaries: couple.anniversaries,
                            ),
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
                          const Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 8),
                          const Text('일정을 불러오지 못했습니다.'),
                          TextButton(
                            onPressed: () =>
                                ref.invalidate(eventsStreamProvider),
                            child: const Text('다시 시도'),
                          ),
                        ],
                      ),
                    )
                  : _MonthPager(onDayTap: openDay),
            ),
          ],
        ),
      ),
      floatingActionButton: _FabMenu(
        onToday: goToToday,
        selectedDay: selectedDay,
      ),
    );
  }
}

/// 오른쪽 아래 원형 메뉴 — 누르면 작은 원 버튼들이 펼쳐진다.
class _FabMenu extends StatefulWidget {
  final VoidCallback onToday;
  final DateTime selectedDay;
  const _FabMenu({required this.onToday, required this.selectedDay});

  @override
  State<_FabMenu> createState() => _FabMenuState();
}

class _FabMenuState extends State<_FabMenu>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  bool _open = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _open = !_open);
    _open ? _controller.forward() : _controller.reverse();
  }

  Widget _item(int index, IconData icon, String label, VoidCallback onTap) {
    final anim = CurvedAnimation(
      parent: _controller,
      curve: Interval(0.1 * index, 1, curve: Curves.easeOutBack),
    );
    return ScaleTransition(
      scale: anim,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
            const SizedBox(width: 10),
            FloatingActionButton.small(
              heroTag: 'fab_$label',
              backgroundColor: Colors.white,
              foregroundColor: _purple,
              onPressed: () {
                _toggle();
                onTap();
              },
              child: Icon(icon),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_open || _controller.isAnimating) ...[
          _item(4, Icons.settings_outlined, '설정',
              () => context.push('/settings')),
          _item(3, Icons.notifications_outlined, '알림 기록',
              () => context.push('/settings/notifications')),
          _item(2, Icons.search, '검색', () => context.push('/search')),
          _item(1, Icons.today, '오늘', widget.onToday),
          _item(0, Icons.edit_calendar, '일정 추가',
              () => context.push('/event/new', extra: widget.selectedDay)),
        ],
        FloatingActionButton(
          heroTag: 'fab_main',
          backgroundColor: _purple,
          onPressed: _toggle,
          child: AnimatedRotation(
            turns: _open ? 0.125 : 0,
            duration: const Duration(milliseconds: 220),
            child: const Icon(Icons.add, color: Colors.white, size: 30),
          ),
        ),
      ],
    );
  }
}

/// 좌우 스와이프로 월 이동하는 페이저. 화살표/오늘 버튼(focusedDateProvider 변경)도
/// 애니메이션으로 따라간다.
class _MonthPager extends ConsumerStatefulWidget {
  final ValueChanged<DateTime> onDayTap;
  const _MonthPager({required this.onDayTap});

  @override
  ConsumerState<_MonthPager> createState() => _MonthPagerState();
}

class _MonthPagerState extends ConsumerState<_MonthPager> {
  static final DateTime _base = DateTime(2020, 1);
  late final PageController _controller;
  bool _animating = false;

  int _indexOf(DateTime month) =>
      (month.year - _base.year) * 12 + (month.month - _base.month);

  DateTime _monthAt(int index) => DateTime(_base.year, _base.month + index);

  @override
  void initState() {
    super.initState();
    _controller = PageController(
      initialPage: _indexOf(ref.read(focusedDateProvider)),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(focusedDateProvider, (prev, next) {
      final target = _indexOf(next);
      if (_controller.hasClients && _controller.page?.round() != target) {
        _animating = true;
        _controller
            .animateToPage(
              target,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            )
            .whenComplete(() => _animating = false);
      }
    });

    final selectedDay = ref.watch(selectedDateProvider);
    final events = ref.watch(eventsStreamProvider).valueOrNull ?? [];
    final anniversaries =
        ref.watch(coupleStreamProvider).valueOrNull?.anniversaries ?? const [];

    return PageView.builder(
      controller: _controller,
      onPageChanged: (index) {
        if (_animating) return;
        final month = _monthAt(index);
        final current = ref.read(focusedDateProvider);
        if (current.year != month.year || current.month != month.month) {
          ref.read(focusedDateProvider.notifier).state = month;
        }
      },
      itemBuilder: (context, index) {
        final month = _monthAt(index);
        final monthEnd = DateTime(month.year, month.month + 1, 0);
        final expanded = expandRecurringForRange(events, month, monthEnd);
        return Consumer(
          builder: (context, ref, _) => MonthGrid(
            month: month,
            events: [
              ...expanded,
              ...anniversaryEventsForMonth(anniversaries, month),
            ],
            holidays:
                ref.watch(koreanHolidaysProvider(month.year)).valueOrNull ??
                const <KoreanHoliday>[],
            selectedDay: selectedDay,
            onDayTap: widget.onDayTap,
          ),
        );
      },
    );
  }
}

class _DaySheet extends ConsumerWidget {
  final DateTime day;

  const _DaySheet({required this.day});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allEvents =
        ref.watch(eventsStreamProvider).valueOrNull ?? <EventModel>[];
    final events = eventsForDay(allEvents, day);
    final holidays =
        ref.watch(koreanHolidaysProvider(day.year)).valueOrNull ??
        const <KoreanHoliday>[];
    final holidayName = koreanHolidayNameForDate(
      groupKoreanHolidaysByDate(holidays),
      day,
    );
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
            if (holidayName != null)
              ListTile(
                dense: true,
                leading: const Icon(Icons.flag_outlined, color: Colors.red),
                title: Text(
                  holidayName,
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: const Text('대한민국 공휴일'),
              ),
            if (events.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Text(
                  '일정이 없습니다',
                  style: TextStyle(color: Colors.grey[400]),
                ),
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
