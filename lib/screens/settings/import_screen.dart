import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/event_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/calendar_provider.dart';
import '../../utils/import_utils.dart';
import '../../widgets/app_surface.dart';

class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  final DeviceCalendarPlugin _calendarPlugin = DeviceCalendarPlugin();

  bool _isLoading = true;
  bool _hasPermission = false;
  bool _isImporting = false;
  String? _errorMessage;
  List<Calendar> _calendars = const [];
  String? _selectedCalendarId;
  List<Event> _deviceEvents = const [];
  Set<int> _selectedIndexes = <int>{};
  int _eventRequestId = 0;

  @override
  void initState() {
    super.initState();
    _checkAndRequestPermission();
  }

  Future<void> _checkAndRequestPermission() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final current = await _calendarPlugin.hasPermissions();
      var granted = current.data == true;
      if (!granted) {
        final requested = await _calendarPlugin.requestPermissions();
        granted = requested.data == true;
      }
      if (!mounted) return;

      if (!granted) {
        setState(() {
          _hasPermission = false;
          _isLoading = false;
        });
        return;
      }

      setState(() => _hasPermission = true);
      await _retrieveCalendars();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasPermission = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _retrieveCalendars() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _calendarPlugin.retrieveCalendars();
      if (result.hasErrors || result.data == null) {
        throw StateError('캘린더 목록 조회 실패');
      }

      final calendars = result.data!
          .where((calendar) => calendar.id?.isNotEmpty == true)
          .toList(growable: false);
      if (!mounted) return;

      final firstCalendarId = calendars.isEmpty ? null : calendars.first.id;
      setState(() {
        _calendars = calendars;
        _selectedCalendarId = firstCalendarId;
        _deviceEvents = const [];
        _selectedIndexes = <int>{};
      });

      if (firstCalendarId == null) {
        setState(() => _isLoading = false);
        return;
      }
      await _retrieveEvents(firstCalendarId);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = '캘린더를 불러오지 못했습니다';
      });
    }
  }

  Future<void> _retrieveEvents(String calendarId) async {
    final requestId = ++_eventRequestId;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final now = DateTime.now();
      final result = await _calendarPlugin.retrieveEvents(
        calendarId,
        RetrieveEventsParams(
          startDate: now,
          endDate: now.add(const Duration(days: 90)),
        ),
      );
      if (result.hasErrors || result.data == null) {
        throw StateError('이벤트 조회 실패');
      }

      final events = result.data!
          .where((event) => event.start != null)
          .toList(growable: false);
      final existingEvents =
          ref.read(eventsStreamProvider).valueOrNull ?? const [];
      final selectedIndexes = <int>{};
      for (var index = 0; index < events.length; index++) {
        final event = events[index];
        if (!isDuplicateEvent(
          existingEvents,
          title: _eventTitle(event),
          start: event.start!,
          isAllDay: event.allDay ?? false,
        )) {
          selectedIndexes.add(index);
        }
      }

      if (!mounted || requestId != _eventRequestId) return;
      setState(() {
        _deviceEvents = events;
        _selectedIndexes = selectedIndexes;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted || requestId != _eventRequestId) return;
      setState(() {
        _deviceEvents = const [];
        _selectedIndexes = <int>{};
        _isLoading = false;
        _errorMessage = '일정을 불러오지 못했습니다';
      });
    }
  }

  String _eventTitle(Event event) {
    final title = event.title?.trim() ?? '';
    return title.isEmpty ? '(제목 없음)' : title;
  }

  String _eventSubtitle(Event event, {required bool isDuplicate}) {
    final start = event.start!;
    final isAllDay = event.allDay ?? false;
    final dateText = isAllDay
        ? '${DateFormat('M월 d일 (E)', 'ko_KR').format(start)} 종일'
        : DateFormat('M월 d일 (E) HH:mm', 'ko_KR').format(start);
    return isDuplicate ? '$dateText · 이미 있음' : dateText;
  }

  Future<void> _importSelectedEvents() async {
    final existingEvents =
        ref.read(eventsStreamProvider).valueOrNull ?? const [];
    final indexes = _selectedIndexes.toList()..sort();
    final eventsToImport = indexes
        .where((index) => index >= 0 && index < _deviceEvents.length)
        .map((index) => _deviceEvents[index])
        .where(
          (event) => !isDuplicateEvent(
            existingEvents,
            title: _eventTitle(event),
            start: event.start!,
            isAllDay: event.allDay ?? false,
          ),
        )
        .toList(growable: false);
    if (eventsToImport.isEmpty) return;

    setState(() => _isImporting = true);
    try {
      final myUid = ref.read(authStateProvider).valueOrNull?.uid ?? '';
      final couple = ref.read(coupleStreamProvider).valueOrNull;
      final color = couple == null
          ? 0xFF42A5F5
          : couple.ownerUid == myUid
          ? couple.ownerColor
          : couple.partnerColor;
      final firestoreService = ref.read(firestoreServiceProvider);

      for (final event in eventsToImport) {
        final draft = deviceEventToDraft(
          title: _eventTitle(event),
          start: event.start!,
          end: event.end,
          isAllDay: event.allDay ?? false,
          coupleId: couple?.coupleId ?? '',
          myUid: myUid,
          color: color,
        );
        await firestoreService.addEvent(draft);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${eventsToImport.length}개 가져왔습니다')),
      );
      context.pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isImporting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('일정을 가져오지 못했습니다')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final existingEvents =
        ref.watch(eventsStreamProvider).valueOrNull ?? const [];
    final selectableSelectedCount = _selectedIndexes.where((index) {
      if (index < 0 || index >= _deviceEvents.length) return false;
      final event = _deviceEvents[index];
      return !isDuplicateEvent(
        existingEvents,
        title: _eventTitle(event),
        start: event.start!,
        isAllDay: event.allDay ?? false,
      );
    }).length;

    return Scaffold(
      appBar: AppBar(title: const Text('기기 캘린더 가져오기')),
      body: _isLoading && !_hasPermission
          ? const Center(child: CircularProgressIndicator())
          : !_hasPermission
          ? _PermissionDeniedView(onRetry: _checkAndRequestPermission)
          : _buildCalendarBody(existingEvents),
      bottomNavigationBar: _hasPermission && !_isLoading
          ? SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: selectableSelectedCount == 0 || _isImporting
                      ? null
                      : _importSelectedEvents,
                  child: Text('$selectableSelectedCount개 가져오기'),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildCalendarBody(List<EventModel> existingEvents) {
    if (_isLoading && _calendars.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return AppPageBody(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.mobile_friendly_outlined,
                  color: colors.onPrimaryContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '선택한 기기 캘린더에서 앞으로 90일의 일정을 가져옵니다.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _selectedCalendarId,
            decoration: const InputDecoration(
              labelText: '가져올 캘린더',
              prefixIcon: Icon(Icons.calendar_month_outlined),
            ),
            items: _calendars
                .map(
                  (calendar) => DropdownMenuItem(
                    value: calendar.id,
                    child: Text(
                      calendar.name?.trim().isNotEmpty == true
                          ? calendar.name!
                          : '이름 없는 캘린더',
                    ),
                  ),
                )
                .toList(growable: false),
            onChanged: _isLoading
                ? null
                : (calendarId) {
                    if (calendarId == null ||
                        calendarId == _selectedCalendarId) {
                      return;
                    }
                    setState(() => _selectedCalendarId = calendarId);
                    _retrieveEvents(calendarId);
                  },
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? AppEmptyState(
                    icon: Icons.cloud_off_outlined,
                    title: _errorMessage!,
                    message: '캘린더를 다시 선택하거나 잠시 후 시도해 주세요.',
                  )
                : _deviceEvents.isEmpty
                ? const AppEmptyState(
                    icon: Icons.event_busy_outlined,
                    title: '가져올 일정이 없습니다',
                    message: '선택한 캘린더의 앞으로 90일이 비어 있어요.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(top: 4, bottom: 12),
                    itemCount: _deviceEvents.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final event = _deviceEvents[index];
                      final duplicate = isDuplicateEvent(
                        existingEvents,
                        title: _eventTitle(event),
                        start: event.start!,
                        isAllDay: event.allDay ?? false,
                      );
                      return Card(
                        child: CheckboxListTile(
                          value: !duplicate && _selectedIndexes.contains(index),
                          title: Text(
                            _eventTitle(event),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            _eventSubtitle(event, isDuplicate: duplicate),
                          ),
                          onChanged: duplicate
                              ? null
                              : (checked) {
                                  setState(() {
                                    if (checked == true) {
                                      _selectedIndexes.add(index);
                                    } else {
                                      _selectedIndexes.remove(index);
                                    }
                                  });
                                },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _PermissionDeniedView extends StatelessWidget {
  const _PermissionDeniedView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: Icons.calendar_month_outlined,
      title: '캘린더 권한이 필요합니다',
      message: '기기 일정을 확인하려면 캘린더 접근을 허용해 주세요.',
      action: FilledButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.lock_open_outlined),
        label: const Text('권한 다시 요청'),
      ),
    );
  }
}
