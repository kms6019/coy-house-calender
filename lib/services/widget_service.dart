import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import '../models/anniversary_model.dart';
import '../models/event_model.dart';
import '../utils/dday_utils.dart';
import '../utils/event_utils.dart';

class WidgetService {
  static const _androidProvider = 'CalendarWidgetProvider';

  static bool get _supported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static Future<void> update(
    List<EventModel> allEvents, {
    List<AnniversaryModel> anniversaries = const [],
  }) async {
    if (!_supported) return;
    try {
      final now = DateTime.now();
      final today = DateUtils.dateOnly(now);
      final todayEvents = eventsForDay(allEvents, today).take(3).toList();

      final eventsJson = jsonEncode(todayEvents.map((e) {
        final timeFmt = DateFormat('HH:mm');
        return {
          'title':
              e.icon?.isNotEmpty == true ? '${e.icon} ${e.title}' : e.title,
          'time': e.isAllDay ? '종일' : timeFmt.format(e.startDateTime),
        };
      }).toList());

      final todayLabel =
          DateFormat('M월 d일 (E)', 'ko_KR').format(now);

      await HomeWidget.saveWidgetData<String>(
          'calendar_widget_events', eventsJson);
      await HomeWidget.saveWidgetData<String>(
          'calendar_widget_today', todayLabel);
      await HomeWidget.saveWidgetData<String>(
          'calendar_widget_dday', _dDayLine(anniversaries, now));
      await HomeWidget.updateWidget(androidName: _androidProvider);
    } catch (e) {
      debugPrint('[WidgetService] update error: $e');
    }
  }

  /// 도래 임박 annual 1개 + 대표(가장 오래된) countUp 1개. 없으면 빈 문자열.
  static String _dDayLine(List<AnniversaryModel> anniversaries, DateTime now) {
    if (anniversaries.isEmpty) return '';
    final sorted = sortedForDisplay(anniversaries, now);
    final parts = <String>[];
    final annual = sorted
        .where((a) => a.type == AnniversaryType.annual)
        .take(1);
    final countUp = sorted
        .where((a) => a.type == AnniversaryType.countUp)
        .take(1);
    for (final a in [...countUp, ...annual]) {
      parts.add('${a.title} ${dDayLabel(a, now)}');
    }
    return parts.join(' · ');
  }
}
