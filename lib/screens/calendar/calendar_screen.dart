import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/event_model.dart';
import '../../models/korean_holiday.dart';
import '../../providers/calendar_provider.dart';
import '../../utils/dday_utils.dart';
import '../../utils/event_utils.dart';
import '../../widgets/app_surface.dart';
import '../event/event_list_tile.dart';
import 'anniversary_chips.dart';
import 'month_grid.dart';

const _weekdayLabels = ['일', '월', '화', '수', '목', '금', '토'];

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
        showDragHandle: true,
        useSafeArea: true,
        builder: (sheetContext) => _DaySheet(day: day),
      );
    }

    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                    child: Row(
                      children: [
                        coupleAsync.when(
                          data: (couple) => Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: colors.surface.withValues(alpha: 0.66),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              couple?.isLinked == true
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: colors.primary,
                              size: 20,
                            ),
                          ),
                          loading: () => const SizedBox(width: 40, height: 40),
                          error: (err, st) =>
                              const SizedBox(width: 40, height: 40),
                        ),
                        const Spacer(),
                        IconButton.filledTonal(
                          tooltip: '이전 달',
                          icon: const Icon(Icons.chevron_left),
                          onPressed: () => changeMonth(-1),
                        ),
                        InkWell(
                          onTap: goToToday,
                          borderRadius: BorderRadius.circular(18),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 9,
                            ),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              child: Text(
                                DateFormat('yyyy년 M월').format(focusedDay),
                                key: ValueKey(
                                  '${focusedDay.year}-${focusedDay.month}',
                                ),
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: colors.onPrimaryContainer,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                        IconButton.filledTonal(
                          tooltip: '다음 달',
                          icon: const Icon(Icons.chevron_right),
                          onPressed: () => changeMonth(1),
                        ),
                        const Spacer(),
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: eventsAsync.isLoading
                              ? Padding(
                                  padding: const EdgeInsets.all(11),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: colors.primary,
                                  ),
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                  coupleAsync.maybeWhen(
                    data: (couple) => couple == null
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: AnniversaryChips(
                              anniversaries: couple.anniversaries,
                            ),
                          ),
                    orElse: () => const SizedBox.shrink(),
                  ),
                  Row(
                    children: List.generate(7, (i) {
                      final color = i == 0
                          ? colors.error
                          : i == 6
                          ? colors.primary
                          : colors.onPrimaryContainer;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            _weekdayLabels[i],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: color,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
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
                  ? AppEmptyState(
                      icon: Icons.cloud_off_outlined,
                      title: '일정을 불러오지 못했습니다',
                      message: '잠시 후 다시 시도해 주세요.',
                      action: FilledButton.tonalIcon(
                        onPressed: () => ref.invalidate(eventsStreamProvider),
                        icon: const Icon(Icons.refresh),
                        label: const Text('다시 시도'),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: colors.outlineVariant.withValues(alpha: 0.6),
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: _MonthPager(onDayTap: openDay),
                        ),
                      ),
                    ),
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
    final colors = Theme.of(context).colorScheme;
    final anim = CurvedAnimation(
      parent: _controller,
      curve: Interval(0.1 * index, 1, curve: Curves.easeOutBack),
    );
    return FadeTransition(
      opacity: anim,
      child: ScaleTransition(
        scale: anim,
        alignment: Alignment.bottomRight,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: colors.inverseSurface,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: colors.shadow.withValues(alpha: 0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: colors.onInverseSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FloatingActionButton.small(
                heroTag: 'fab_$label',
                backgroundColor: colors.secondaryContainer,
                foregroundColor: colors.onSecondaryContainer,
                elevation: 2,
                onPressed: () {
                  _toggle();
                  onTap();
                },
                child: Icon(icon),
              ),
            ],
          ),
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
          _item(
            4,
            Icons.settings_outlined,
            '설정',
            () => context.push('/settings'),
          ),
          _item(
            3,
            Icons.notifications_outlined,
            '알림 기록',
            () => context.push('/settings/notifications'),
          ),
          _item(2, Icons.search, '검색', () => context.push('/search')),
          _item(1, Icons.today, '오늘', widget.onToday),
          _item(
            0,
            Icons.edit_calendar,
            '일정 추가',
            () => context.push('/event/new', extra: widget.selectedDay),
          ),
        ],
        FloatingActionButton(
          heroTag: 'fab_main',
          onPressed: _toggle,
          child: AnimatedRotation(
            turns: _open ? 0.125 : 0,
            duration: const Duration(milliseconds: 220),
            child: const Icon(Icons.add, size: 30),
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.78,
      ),
      child: AppPageBody(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('M월 d일 E요일', 'ko_KR').format(day),
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        events.isEmpty ? '비어 있는 하루예요' : '일정 ${events.length}개',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton.filled(
                  tooltip: '일정 추가',
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.push('/event/new', extra: day);
                  },
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (holidayName != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.errorContainer,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Icon(Icons.flag_outlined, color: colors.onErrorContainer),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            holidayName,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: colors.onErrorContainer,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '대한민국 공휴일',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onErrorContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (events.isEmpty)
              const AppEmptyState(
                icon: Icons.event_available_outlined,
                title: '일정이 없습니다',
                message: '둘만의 새 일정을 추가해 보세요.',
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: events.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => EventListTile(event: events[i]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
