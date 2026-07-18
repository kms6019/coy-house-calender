import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/event_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/calendar_provider.dart';
import '../../utils/import_utils.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('일정을 가져오지 못했습니다')),
      );
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

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: DropdownButtonFormField<String>(
            initialValue: _selectedCalendarId,
            decoration: const InputDecoration(
              labelText: '캘린더',
              border: OutlineInputBorder(),
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
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                  ? Center(child: Text(_errorMessage!))
                  : _deviceEvents.isEmpty
                      ? const Center(child: Text('가져올 일정이 없습니다'))
                      : ListView.builder(
                          itemCount: _deviceEvents.length,
                          itemBuilder: (context, index) {
                            final event = _deviceEvents[index];
                            final duplicate = isDuplicateEvent(
                              existingEvents,
                              title: _eventTitle(event),
                              start: event.start!,
                              isAllDay: event.allDay ?? false,
                            );
                            return CheckboxListTile(
                              value:
                                  !duplicate && _selectedIndexes.contains(index),
                              title: Text(_eventTitle(event)),
                              subtitle: Text(
                                _eventSubtitle(
                                  event,
                                  isDuplicate: duplicate,
                                ),
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
                            );
                          },
                        ),
        ),
      ],
    );
  }
}

class _PermissionDeniedView extends StatelessWidget {
  const _PermissionDeniedView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('캘린더 권한이 필요합니다'),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onRetry,
            child: const Text('권한 다시 요청'),
          ),
        ],
      ),
    );
  }
}
