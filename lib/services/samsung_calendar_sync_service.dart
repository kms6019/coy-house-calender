import 'dart:io' show Platform;
import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import '../models/event_model.dart';
import 'calendar_event_mapping.dart';
import 'device_calendar_event_builder.dart';

class SamsungCalendarSyncService {
  static const _calendarName = 'CoyHouseCalender';

  final DeviceCalendarPlugin _plugin;
  final CalendarEventMapping _mapping;

  Future<String?>? _ensureCalendarFuture;

  SamsungCalendarSyncService({
    DeviceCalendarPlugin? plugin,
    CalendarEventMapping? mapping,
  })  : _plugin = plugin ?? DeviceCalendarPlugin(),
        _mapping = mapping ?? CalendarEventMapping();

  bool get _supported => !kIsWeb && Platform.isAndroid;

  Future<String?> _ensureCalendarExists() {
    return _ensureCalendarFuture ??= _doEnsureCalendarExists().whenComplete(() {
      _ensureCalendarFuture = null;
    });
  }

  Future<String?> _doEnsureCalendarExists() async {
    final cached = await _mapping.getCalendarId();
    if (cached != null) return cached;

    final hasPermissions = await _plugin.hasPermissions();
    if (hasPermissions.hasErrors) {
      debugPrint('[SamsungCalendarSync] hasPermissions error: ${hasPermissions.errors}');
    }
    if (hasPermissions.data != true) {
      final requested = await _plugin.requestPermissions();
      if (requested.hasErrors) {
        debugPrint('[SamsungCalendarSync] requestPermissions error: ${requested.errors}');
      }
      if (requested.data != true) {
        debugPrint('[SamsungCalendarSync] calendar permission denied');
        return null;
      }
    }

    final calendarsResult = await _plugin.retrieveCalendars();
    if (calendarsResult.hasErrors || calendarsResult.data == null) {
      debugPrint('[SamsungCalendarSync] retrieveCalendars error: ${calendarsResult.errors}');
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
      debugPrint('[SamsungCalendarSync] createCalendar error: ${createResult.errors}');
    }
    final newId = createResult.data;
    if (newId != null) await _mapping.setCalendarId(newId);
    return newId;
  }

  Future<void> syncEventCreate(EventModel event) async {
    if (!_supported) return;
    try {
      final calendarId = await _ensureCalendarExists();
      if (calendarId == null) return;
      final deviceEvent = buildDeviceCalendarEvent(event, calendarId: calendarId);
      final result = await _plugin.createOrUpdateEvent(deviceEvent);
      if (result != null && result.hasErrors) {
        debugPrint('[SamsungCalendarSync] createOrUpdateEvent error: ${result.errors}');
      }
      final deviceEventId = result?.data;
      if (deviceEventId != null) {
        await _mapping.setDeviceEventId(event.id, deviceEventId);
      }
    } catch (e) {
      debugPrint('[SamsungCalendarSync] create error: $e');
    }
  }

  Future<void> syncEventUpdate(EventModel event) async {
    if (!_supported) return;
    try {
      final calendarId = await _ensureCalendarExists();
      if (calendarId == null) return;
      final existingDeviceId = await _mapping.getDeviceEventId(event.id);
      final deviceEvent = buildDeviceCalendarEvent(
        event,
        calendarId: calendarId,
        deviceEventId: existingDeviceId,
      );
      final result = await _plugin.createOrUpdateEvent(deviceEvent);
      if (result != null && result.hasErrors) {
        debugPrint('[SamsungCalendarSync] createOrUpdateEvent error: ${result.errors}');
      }
      final deviceEventId = result?.data;
      if (deviceEventId != null) {
        await _mapping.setDeviceEventId(event.id, deviceEventId);
      }
    } catch (e) {
      debugPrint('[SamsungCalendarSync] update error: $e');
    }
  }

  Future<void> syncEventDelete(String eventId) async {
    if (!_supported) return;
    try {
      final calendarId = await _mapping.getCalendarId();
      final deviceEventId = await _mapping.getDeviceEventId(eventId);
      if (calendarId == null || deviceEventId == null) return;
      final result = await _plugin.deleteEvent(calendarId, deviceEventId);
      if (result.hasErrors) {
        debugPrint('[SamsungCalendarSync] deleteEvent error: ${result.errors}');
      }
      await _mapping.removeDeviceEventId(eventId);
    } catch (e) {
      debugPrint('[SamsungCalendarSync] delete error: $e');
    }
  }
}
