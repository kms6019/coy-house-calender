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

  SamsungCalendarSyncService({
    DeviceCalendarPlugin? plugin,
    CalendarEventMapping? mapping,
  })  : _plugin = plugin ?? DeviceCalendarPlugin(),
        _mapping = mapping ?? CalendarEventMapping();

  bool get _supported => !kIsWeb && Platform.isAndroid;

  Future<String?> _ensureCalendarExists() async {
    final cached = await _mapping.getCalendarId();
    if (cached != null) return cached;

    final hasPermissions = await _plugin.hasPermissions();
    if (hasPermissions.data != true) {
      final requested = await _plugin.requestPermissions();
      if (requested.data != true) return null;
    }

    final calendarsResult = await _plugin.retrieveCalendars();
    final calendars = calendarsResult.data;
    final existing = calendars?.where((c) => c.name == _calendarName).toList();
    if (existing != null && existing.isNotEmpty && existing.first.id != null) {
      final id = existing.first.id!;
      await _mapping.setCalendarId(id);
      return id;
    }

    final createResult = await _plugin.createCalendar(_calendarName);
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
      await _plugin.deleteEvent(calendarId, deviceEventId);
      await _mapping.removeDeviceEventId(eventId);
    } catch (e) {
      debugPrint('[SamsungCalendarSync] delete error: $e');
    }
  }
}
