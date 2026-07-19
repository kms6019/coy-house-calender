import 'dart:io' show Platform;
import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import '../models/event_model.dart';
import 'calendar_event_mapping.dart';
import 'device_calendar_event_builder.dart';

class SamsungSyncSummary {
  int created = 0;
  int updated = 0;
  int deleted = 0;
  int failed = 0;
  String? firstError;
}

class SamsungCalendarSyncService {
  static const _calendarName = 'CoyHouseCalender';

  final DeviceCalendarPlugin _plugin;
  final CalendarEventMapping _mapping;

  SamsungCalendarSyncService({
    DeviceCalendarPlugin? plugin,
    CalendarEventMapping? mapping,
  })  : _plugin = plugin ?? DeviceCalendarPlugin(),
        _mapping = mapping ?? CalendarEventMapping();

  bool get _supported => !kIsWeb && Platform.isAndroid;

  String _formatErrors(List<ResultError> errors) =>
      errors.map((e) => '${e.errorCode}: ${e.errorMessage}').join(', ');

  Future<String?> _ensureCalendarExists() async {
    final cached = await _mapping.getCalendarId();
    if (cached != null) return cached;

    final hasPermissions = await _plugin.hasPermissions();
    if (hasPermissions.hasErrors) {
      debugPrint('[SamsungCalendarSync] hasPermissions error: ${_formatErrors(hasPermissions.errors)}');
    }
    if (hasPermissions.data != true) {
      final requested = await _plugin.requestPermissions();
      if (requested.hasErrors) {
        debugPrint('[SamsungCalendarSync] requestPermissions error: ${_formatErrors(requested.errors)}');
      }
      if (requested.data != true) {
        debugPrint('[SamsungCalendarSync] calendar permission denied');
        return null;
      }
    }

    final calendarsResult = await _plugin.retrieveCalendars();
    if (calendarsResult.hasErrors || calendarsResult.data == null) {
      debugPrint('[SamsungCalendarSync] retrieveCalendars error: ${_formatErrors(calendarsResult.errors)}');
      return null;
    }
    final calendars = calendarsResult.data;
    final existing = calendars?.where((c) => c.name == _calendarName).toList();
    if (existing != null && existing.isNotEmpty && existing.first.id != null) {
      final id = existing.first.id!;
      await _mapping.setCalendarId(id);
      return id;
    }

    final createResult = await _plugin.createCalendar(_calendarName);
    if (createResult.hasErrors) {
      debugPrint('[SamsungCalendarSync] createCalendar error: ${_formatErrors(createResult.errors)}');
    }
    final newId = createResult.data;
    if (newId != null) await _mapping.setCalendarId(newId);
    return newId;
  }

  /// 성공 시 null, 실패 시 에러 메시지 반환.
  Future<String?> syncEventCreate(EventModel event) async {
    if (!_supported) return null;
    try {
      final calendarId = await _ensureCalendarExists();
      if (calendarId == null) return '캘린더 권한/생성 실패';
      final deviceEvent = buildDeviceCalendarEvent(event, calendarId: calendarId);
      final result = await _plugin.createOrUpdateEvent(deviceEvent);
      if (result != null && result.hasErrors) {
        final msg = _formatErrors(result.errors);
        debugPrint('[SamsungCalendarSync] createOrUpdateEvent error: $msg');
        return msg;
      }
      final deviceEventId = result?.data;
      if (deviceEventId == null) return 'createOrUpdateEvent가 ID를 반환하지 않음';
      await _mapping.setDeviceEventId(event.id, deviceEventId);
      return null;
    } catch (e) {
      debugPrint('[SamsungCalendarSync] create error: $e');
      return '$e';
    }
  }

  /// 성공 시 null, 실패 시 에러 메시지 반환.
  Future<String?> syncEventUpdate(EventModel event) async {
    if (!_supported) return null;
    try {
      final calendarId = await _ensureCalendarExists();
      if (calendarId == null) return '캘린더 권한/생성 실패';
      final existingDeviceId = await _mapping.getDeviceEventId(event.id);
      final deviceEvent = buildDeviceCalendarEvent(
        event,
        calendarId: calendarId,
        deviceEventId: existingDeviceId,
      );
      final result = await _plugin.createOrUpdateEvent(deviceEvent);
      if (result != null && result.hasErrors) {
        final msg = _formatErrors(result.errors);
        debugPrint('[SamsungCalendarSync] createOrUpdateEvent error: $msg');
        return msg;
      }
      final deviceEventId = result?.data;
      if (deviceEventId != null) {
        await _mapping.setDeviceEventId(event.id, deviceEventId);
      }
      return null;
    } catch (e) {
      debugPrint('[SamsungCalendarSync] update error: $e');
      return '$e';
    }
  }

  /// 매핑에 저장된 기기 이벤트 ID 중 실제 기기 캘린더에 남아 있는 것만 반환.
  Future<Set<String>> _retrieveExistingDeviceIds(
    Iterable<String> deviceIds,
  ) async {
    final ids = deviceIds.toList();
    if (ids.isEmpty) return {};
    final calendarId = await _mapping.getCalendarId();
    if (calendarId == null) return {};
    // 기간 미지정 시 플러그인이 끝을 Long.MAX_VALUE로 잡아 Instances 쿼리가
    // 깨질 수 있어 명시적 범위를 함께 전달한다.
    final now = DateTime.now();
    final result = await _plugin.retrieveEvents(
      calendarId,
      RetrieveEventsParams(
        eventIds: ids,
        startDate: DateTime(now.year - 5),
        endDate: DateTime(now.year + 5),
      ),
    );
    if (result.hasErrors || result.data == null) {
      debugPrint('[SamsungCalendarSync] retrieveEvents error: ${_formatErrors(result.errors)}');
      // 조회 실패 시 전부 존재한다고 보고 기존 update 경로 유지 (중복 생성 방지)
      return ids.toSet();
    }
    return result.data!
        .map((e) => e.eventId)
        .whereType<String>()
        .toSet();
  }

  /// 전용 캘린더 안에서 매핑에 없는 고아 이벤트 삭제.
  /// CoyHouseCalender 캘린더는 앱 전용이므로 매핑에 없는 항목은
  /// 과거 버그로 남은 찌꺼기다 (예: 날짜 수정 중 매핑이 덮여 고아가 된 항목).
  Future<int> _deleteOrphans() async {
    final calendarId = await _mapping.getCalendarId();
    if (calendarId == null) return 0;
    final now = DateTime.now();
    final result = await _plugin.retrieveEvents(
      calendarId,
      RetrieveEventsParams(
        startDate: DateTime(now.year - 5),
        endDate: DateTime(now.year + 5),
      ),
    );
    if (result.hasErrors || result.data == null) return 0;
    final mappedIds = (await _mapping.loadAll()).values.toSet();
    final orphanIds = result.data!
        .map((e) => e.eventId)
        .whereType<String>()
        .where((id) => !mappedIds.contains(id))
        .toSet();
    var deleted = 0;
    for (final id in orphanIds) {
      final del = await _plugin.deleteEvent(calendarId, id);
      if (del.hasErrors) {
        debugPrint('[SamsungCalendarSync] orphan delete error: ${_formatErrors(del.errors)}');
      } else {
        deleted++;
      }
    }
    return deleted;
  }

  static bool _syncAllInProgress = false;

  /// 커플 이벤트 전체 미러 동기화 — 상대가 올린 일정도 내 기기 캘린더에 반영.
  /// 매핑에 없는 이벤트는 생성, 있는 이벤트는 갱신, 스트림에서 사라진 매핑은 삭제.
  /// proposed(제안 중) 이벤트는 확정 전이므로 제외.
  Future<SamsungSyncSummary> syncAll(List<EventModel> events) async {
    final summary = SamsungSyncSummary();
    if (!_supported || _syncAllInProgress) return summary;
    _syncAllInProgress = true;
    try {
      final map = await _mapping.loadAll();
      final active = events.where((e) => !e.isProposed).toList();
      // 사용자가 삼성캘린더에서 직접 지운 이벤트는 매핑이 남아 있어도
      // 기기에 없으므로 update가 조용히 무시된다 → 실제 존재 여부 확인 후
      // 없으면 생성 경로로 보낸다.
      final existingDeviceIds = await _retrieveExistingDeviceIds(map.values);
      for (final event in active) {
        final deviceId = map[event.id];
        final String? error;
        if (deviceId != null && existingDeviceIds.contains(deviceId)) {
          error = await syncEventUpdate(event);
          if (error == null) summary.updated++;
        } else {
          if (deviceId != null) await _mapping.removeDeviceEventId(event.id);
          error = await syncEventCreate(event);
          if (error == null) summary.created++;
        }
        if (error != null) {
          summary.failed++;
          summary.firstError ??= '${event.title}: $error';
        }
      }
      final activeIds = active.map((e) => e.id).toSet();
      for (final staleId
          in map.keys.where((id) => !activeIds.contains(id)).toList()) {
        await syncEventDelete(staleId);
        summary.deleted++;
      }
      summary.deleted += await _deleteOrphans();
    } catch (e) {
      debugPrint('[SamsungCalendarSync] syncAll error: $e');
      summary.firstError ??= '$e';
    } finally {
      _syncAllInProgress = false;
    }
    return summary;
  }

  Future<void> syncEventDelete(String eventId) async {
    if (!_supported) return;
    try {
      final calendarId = await _mapping.getCalendarId();
      final deviceEventId = await _mapping.getDeviceEventId(eventId);
      if (calendarId == null || deviceEventId == null) return;
      final result = await _plugin.deleteEvent(calendarId, deviceEventId);
      if (result.hasErrors) {
        debugPrint('[SamsungCalendarSync] deleteEvent error: ${_formatErrors(result.errors)}');
      }
      await _mapping.removeDeviceEventId(eventId);
    } catch (e) {
      debugPrint('[SamsungCalendarSync] delete error: $e');
    }
  }
}
