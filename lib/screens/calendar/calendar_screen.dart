import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/event_model.dart';
import '../../models/korean_holiday.dart';
import '../../providers/calendar_provider.dart';
import '../../theme/design_tokens.dart';
import '../../utils/dday_utils.dart';
import '../../utils/event_utils.dart';
import '../../widgets/app_surface.dart';
import '../../widgets/update_prompt.dart';
import 'agenda_list.dart';
import 'anniversary_chips.dart';
import 'month_grid.dart';

const _weekdayLabels = ['일', '월', '화', '수', '목', '금', '토'];

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  static const _expandedKey = 'calendar_month_expanded';

  /// true: 칸마다 일정 제목이 들어간 월 보기. false: 점 + 아래 선택일 일정.
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    // 앱 실행 후 첫 캘린더 진입에서 한 번만 새 버전을 확인한다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) maybePromptUpdate(context);
    });
    SharedPreferences.getInstance().then((prefs) {
      final saved = prefs.getBool(_expandedKey) ?? false;
      if (mounted && saved != _expanded) setState(() => _expanded = saved);
    });
  }

  void _setExpanded(bool value) {
    if (value == _expanded) return;
    setState(() => _expanded = value);
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setBool(_expandedKey, value),
    );
  }

  /// 아래로 밀면 펼치고, 위로 밀면 접는다.
  void _onVerticalDragEnd(DragEndDetails details) {
    final v = details.primaryVelocity ?? 0;
    if (v > 250) _setExpanded(true);
    if (v < -250) _setExpanded(false);
  }

  @override
  Widget build(BuildContext context) {
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

    void selectDay(DateTime day) {
      ref.read(selectedDateProvider.notifier).state = day;
    }

    final t = DesignTokens.of(context);
    final allEvents = eventsAsync.valueOrNull ?? const <EventModel>[];
    final holidays =
        ref.watch(koreanHolidaysProvider(selectedDay.year)).valueOrNull ??
        const <KoreanHoliday>[];

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _MonthHeader(
              month: focusedDay,
              onPrev: () => changeMonth(-1),
              onNext: () => changeMonth(1),
              onToday: goToToday,
              onSearch: () => context.push('/search'),
              loading: eventsAsync.isLoading,
            ),
            coupleAsync.maybeWhen(
              data: (couple) => couple == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 2),
                      child: AnniversaryChips(
                        anniversaries: couple.anniversaries,
                      ),
                    ),
              orElse: () => const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),
            _WeekdayRow(tokens: t),
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) {
                  final gridHeight = _expanded
                      ? box.maxHeight - _handleHeight
                      : _gridHeight;
                  return Column(
                    children: [
                      GestureDetector(
                        onVerticalDragEnd: _onVerticalDragEnd,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOutCubic,
                          height: gridHeight.clamp(0, box.maxHeight),
                          child: eventsAsync.hasError
                              ? AppEmptyState(
                                  icon: Icons.cloud_off_outlined,
                                  title: '일정을 불러오지 못했습니다',
                                  message: '잠시 후 다시 시도해 주세요.',
                                  action: FilledButton.tonalIcon(
                                    onPressed: () =>
                                        ref.invalidate(eventsStreamProvider),
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('다시 시도'),
                                  ),
                                )
                              : _MonthPager(
                                  expanded: _expanded,
                                  onDayTap: (day) {
                                    selectDay(day);
                                    // 펼친 보기에서 날짜를 누르면 그날 일정으로 접는다
                                    _setExpanded(false);
                                  },
                                ),
                        ),
                      ),
                      _ViewHandle(
                        tokens: t,
                        onTap: () => _setExpanded(!_expanded),
                        onVerticalDragEnd: _onVerticalDragEnd,
                      ),
                      if (!_expanded)
                        Expanded(
                          // 목록 맨 위에서 더 끌어내리면 펼친 보기로
                          child: NotificationListener<OverscrollNotification>(
                            onNotification: (n) {
                              if (n.dragDetails != null && n.overscroll < -6) {
                                _setExpanded(true);
                              }
                              return false;
                            },
                            child: AgendaList(
                              day: selectedDay,
                              // 달력 칸에 찍히는 기념일도 그날 목록에 함께 보여 준다
                              events: [
                                ...anniversaryEventsForDay(
                                  coupleAsync.valueOrNull?.anniversaries ??
                                      const [],
                                  selectedDay,
                                ),
                                ...eventsForDay(allEvents, selectedDay),
                              ],
                              holidayName: koreanHolidayNameForDate(
                                groupKoreanHolidaysByDate(holidays),
                                selectedDay,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
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

/// 6주 × 50px + 상단 여백
const double _gridHeight = 6 * 50 + 6;

/// 달력과 일정 목록 사이 손잡이 높이
const double _handleHeight = 20;

/// 달력 ↔ 일정 목록 경계의 손잡이. 누르거나 위아래로 밀어 보기를 바꾼다.
class _ViewHandle extends StatelessWidget {
  final DesignTokens tokens;
  final VoidCallback onTap;
  final GestureDragEndCallback onVerticalDragEnd;
  const _ViewHandle({
    required this.tokens,
    required this.onTap,
    required this.onVerticalDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onVerticalDragEnd: onVerticalDragEnd,
      child: SizedBox(
        height: _handleHeight,
        child: Center(
          child: Container(
            width: 32,
            height: 4,
            decoration: BoxDecoration(
              color: tokens.ink18,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}

/// 초대형 월 숫자 + 이동 컨트롤
class _MonthHeader extends StatelessWidget {
  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final VoidCallback onSearch;
  final bool loading;

  const _MonthHeader({
    required this.month,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
    required this.onSearch,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    final t = DesignTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Row(
                key: ValueKey('${month.year}-${month.month}'),
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '${month.month}',
                    style: TextStyle(
                      fontSize: 44,
                      height: 0.92,
                      fontWeight: FontWeight.w200,
                      letterSpacing: -1.98,
                      color: t.ink,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      '월',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.28,
                        color: t.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Text(
                      '${month.year}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.1,
                        color: t.ink30,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (loading)
            Padding(
              padding: const EdgeInsets.only(right: 6, bottom: 8),
              child: SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.6,
                  color: t.ink30,
                ),
              ),
            ),
          _HeaderButton(onTap: onPrev, tokens: t, child: const Text('‹')),
          _HeaderButton(onTap: onNext, tokens: t, child: const Text('›')),
          const SizedBox(width: 3),
          GestureDetector(
            onTap: onToday,
            child: Container(
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: t.line),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '오늘',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.23,
                  color: t.ink70,
                ),
              ),
            ),
          ),
          const SizedBox(width: 1),
          _HeaderButton(
            onTap: onSearch,
            tokens: t,
            child: Icon(Icons.search, size: 16, color: t.ink45),
          ),
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  final VoidCallback onTap;
  final DesignTokens tokens;
  final Widget child;
  const _HeaderButton({
    required this.onTap,
    required this.tokens,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 30,
        height: 30,
        child: Center(
          child: DefaultTextStyle(
            style: TextStyle(fontSize: 18, color: tokens.ink45),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _WeekdayRow extends StatelessWidget {
  final DesignTokens tokens;
  const _WeekdayRow({required this.tokens});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.hairline)),
      ),
      child: Row(
        children: List.generate(7, (i) {
          return Expanded(
            child: Text(
              _weekdayLabels[i],
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: i == 0
                    ? tokens.sunday
                    : (i == 6 ? tokens.saturday : tokens.ink30),
              ),
            ),
          );
        }),
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
    final tokens = DesignTokens.of(context);
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
        // 디자인 원본: 54px, radius 17, accent 채움, 흰 + 글리프
        GestureDetector(
          onTap: _toggle,
          child: Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tokens.accent,
              borderRadius: BorderRadius.circular(17),
              boxShadow: [
                BoxShadow(
                  color: tokens.accent.withValues(alpha: 0.28),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: AnimatedRotation(
              turns: _open ? 0.125 : 0,
              duration: const Duration(milliseconds: 220),
              child: const Icon(Icons.add, size: 26, color: Colors.white),
            ),
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
  final bool expanded;
  const _MonthPager({required this.onDayTap, required this.expanded});

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
            expanded: widget.expanded,
          ),
        );
      },
    );
  }
}

