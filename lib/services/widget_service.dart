import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import '../models/event_model.dart';

class WidgetService {
  static const _androidProvider = 'CalendarWidgetProvider';

  static bool get _supported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static Future<void> update(List<EventModel> allEvents) async {
    if (!_supported) return;
    try {
      final now = DateTime.now();
      final today = DateUtils.dateOnly(now);
      final todayEvents = allEvents
          .where((e) => DateUtils.dateOnly(e.startDateTime) == today)
          .take(3)
          .toList();

      final eventsJson = jsonEncode(todayEvents.map((e) {
        final timeFmt = DateFormat('HH:mm');
        return {
          'title': e.title,
          'time': e.isAllDay ? '종일' : timeFmt.format(e.startDateTime),
        };
      }).toList());

      final todayLabel =
          DateFormat('M월 d일 (E)', 'ko_KR').format(now);

      await HomeWidget.saveWidgetData<String>(
          'calendar_widget_events', eventsJson);
      await HomeWidget.saveWidgetData<String>(
          'calendar_widget_today', todayLabel);
      await HomeWidget.updateWidget(androidName: _androidProvider);
    } catch (e) {
      debugPrint('[WidgetService] update error: $e');
    }
  }
}
