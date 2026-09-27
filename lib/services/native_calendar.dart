import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

/// 기기 캘린더의 한 항목 (CalendarContract.Calendars)
class NativeCalendar {
  final String id;
  final String name;
  final String accountName;
  final bool isLocal;

  const NativeCalendar({
    required this.id,
    required this.name,
    required this.accountName,
    required this.isLocal,
  });

  factory NativeCalendar.fromMap(Map<dynamic, dynamic> map) => NativeCalendar(
    id: '${map['id']}',
    name: map['name'] as String? ?? '',
    accountName: map['accountName'] as String? ?? '',
    isLocal: map['isLocal'] as bool? ?? false,
  );
}

/// 기기 캘린더의 이벤트 한 건 (CalendarContract.Events 원본 행)
class NativeEvent {
  final String id;
  final String title;
  final int dtstart;
  final bool allDay;

  /// 앱이 심은 마커 (Events.CUSTOM_APP_URI)
  final String? customAppUri;

  const NativeEvent({
    required this.id,
    required this.title,
    required this.dtstart,
    required this.allDay,
    this.customAppUri,
  });

  factory NativeEvent.fromMap(Map<dynamic, dynamic> map) => NativeEvent(
    id: '${map['id']}',
    title: map['title'] as String? ?? '',
    dtstart: (map['dtstart'] as num?)?.toInt() ?? 0,
    allDay: map['allDay'] as bool? ?? false,
    customAppUri: map['customAppUri'] as String?,
  );
}

/// CalendarContract 를 직접 다루는 네이티브 브리지.
///
/// device_calendar 플러그인이 이 프로젝트의 대상 기기(Android 16)에서
/// 캘린더 정보를 전부 null 로 돌려주고 Instances 조회도 빈 목록을 주는 바람에
/// 같은 일정이 수십 개씩 복제됐다. 조회는 Instances 가 아니라 원본 Events
/// 테이블을 쓰고, 캘린더 삭제는 asSyncAdapter 로 처리한다.
class NativeCalendarBridge {
  static const _channel = MethodChannel('coyhouse/calendar');

  static bool get isSupported => !kIsWeb && Platform.isAndroid;

  static Future<List<NativeCalendar>> queryCalendars() async {
    final raw = await _channel.invokeListMethod<dynamic>('queryCalendars');
    return (raw ?? const [])
        .whereType<Map<dynamic, dynamic>>()
        .map(NativeCalendar.fromMap)
        .toList();
  }

  /// 이름이 같은 로컬 캘린더가 있으면 그것을, 없으면 새로 만들어 id 반환.
  static Future<String?> ensureCalendar(String name) =>
      _channel.invokeMethod<String>('ensureCalendar', {'name': name});

  /// 같은 이름의 로컬 캘린더를 전부 삭제하고 지운 개수를 반환.
  static Future<int> deleteCalendarsByName(String name) async =>
      await _channel.invokeMethod<int>('deleteCalendarsByName', {
        'name': name,
      }) ??
      0;

  /// 로컬 캘린더 하나를 id 로 삭제. 로컬이 아니거나 없으면 false.
  static Future<bool> deleteCalendar(String calendarId) async =>
      await _channel.invokeMethod<bool>('deleteCalendar', {
        'calendarId': calendarId,
      }) ??
      false;

  static Future<List<NativeEvent>> queryEvents(String calendarId) async {
    final raw = await _channel.invokeListMethod<dynamic>('queryEvents', {
      'calendarId': calendarId,
    });
    return (raw ?? const [])
        .whereType<Map<dynamic, dynamic>>()
        .map(NativeEvent.fromMap)
        .toList();
  }

  static Future<String?> upsertEvent({
    required String calendarId,
    String? eventId,
    required String title,
    String? description,
    required int dtstart,
    required int dtend,
    required bool allDay,
    required String timeZone,
    String? rrule,
    String? customAppUri,
  }) => _channel.invokeMethod<String>('upsertEvent', {
    'calendarId': calendarId,
    'eventId': eventId,
    'title': title,
    'description': description,
    'dtstart': dtstart,
    'dtend': dtend,
    'allDay': allDay,
    'timeZone': timeZone,
    'rrule': rrule,
    'customAppUri': customAppUri,
  });

  static Future<bool> deleteEvent(String eventId) async =>
      await _channel.invokeMethod<bool>('deleteEvent', {'eventId': eventId}) ??
      false;
}
