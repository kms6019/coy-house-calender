import 'dart:io' show Platform;
import 'package:device_calendar/device_calendar.dart' show DeviceCalendarPlugin;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import '../models/event_model.dart';
import 'calendar_event_mapping.dart';
import 'device_calendar_event_builder.dart';
import 'device_sync_prefs.dart';
import 'native_calendar.dart';

class SamsungSyncSummary {
  int created = 0;
  int updated = 0;
  int deleted = 0;
  int failed = 0;
  String? firstError;

  /// 진단용
  int appCalendars = 0;
  int deviceEvents = 0;
  int duplicatesFound = 0;
  int unmatched = 0;

  String get diagnostics =>
      '캘린더 $appCalendars개 · 기기일정 $deviceEvents건 · '
      '중복 $duplicatesFound건 · 미확인 $unmatched건';
}

/// 마커가 없는 옛 이벤트를 대조하기 위한 보조 지문. 마커가 있으면 쓰지 않는다.
///
/// 종일 일정은 기기에 UTC 자정으로 저장되고 앱은 로컬 시각을 들고 있어
/// epoch 가 시차만큼 어긋난다. 그래서 종일은 epoch 대신 날짜 성분으로 묶는다.
String deviceEventKey(String? title, DateTime? start, {bool allDay = false}) {
  final t = (title ?? '').trim();
  if (start == null) return '$t|0';
  if (allDay) {
    final y = start.year.toString().padLeft(4, '0');
    final m = start.month.toString().padLeft(2, '0');
    final d = start.day.toString().padLeft(2, '0');
    return '$t|D$y-$m-$d';
  }
  return '$t|${start.millisecondsSinceEpoch}';
}

/// 중복 판정에 쓰는 기기 이벤트 1건.
typedef DeviceEventRef = ({String id, String? marker, String key});

/// 같은 앱 일정을 가리키는 사본 중 하나만 남기고 나머지 id를 돌려준다.
///
/// 그룹핑 기준은 **마커 우선**이다. 제목+시작만으로 묶으면 "출근"처럼 제목과
/// 시각이 같은 별개의 정상 일정을 지워버릴 수 있어서, 마커 없는 항목은
/// [knownKeys](앱이 실제로 가진 일정의 지문)에 들어 있을 때만 정리한다.
List<String> duplicateDeviceEventIdsToDelete(
  List<DeviceEventRef> events,
  Set<String> mappedIds, {
  Set<String> knownKeys = const {},
}) {
  final seen = <String>{};
  final groups = <String, List<String>>{};
  for (final e in events) {
    if (!seen.add(e.id)) continue;
    final String group;
    if (e.marker != null) {
      group = 'm:${e.marker}';
    } else if (knownKeys.contains(e.key)) {
      group = 'k:${e.key}';
    } else {
      continue; // 앱이 만든 게 아닐 수 있다 — 건드리지 않는다
    }
    groups.putIfAbsent(group, () => <String>[]).add(e.id);
  }

  final doomed = <String>[];
  for (final ids in groups.values) {
    if (ids.length < 2) continue;
    final keep = ids.firstWhere(mappedIds.contains, orElse: () => ids.first);
    doomed.addAll(ids.where((id) => id != keep));
  }
  return doomed;
}

/// 앱 캘린더가 여러 개 쌓여 있으면 하나만 남긴다.
///
/// 옛 플러그인 시절에 같은 이름의 캘린더가 4개까지 생겼고, 앱은 그중 하나만
/// 동기화하므로 나머지에 남은 사본이 삼성캘린더에 그대로 겹쳐 보였다.
/// 캐시된 캘린더가 살아 있으면 그것을, 아니면 id 가 가장 작은 것을 남긴다.
({String? keep, List<String> extras}) pickAppCalendar(
  List<NativeCalendar> calendars,
  String name,
  String? cachedId,
) {
  final mine = calendars.where((c) => c.isLocal && c.name == name).toList();
  if (mine.isEmpty) return (keep: null, extras: const []);
  final keep = mine.any((c) => c.id == cachedId) ? cachedId! : mine.first.id;
  return (
    keep: keep,
    extras: mine.map((c) => c.id).where((id) => id != keep).toList(),
  );
}

/// 커플 일정을 기기(삼성) 캘린더에 미러링한다.
///
/// device_calendar 플러그인이 대상 기기에서 캘린더 정보를 전부 null 로 돌려주고
/// Instances 조회도 빈 목록을 주는 바람에 같은 일정이 78개까지 복제됐다.
/// 그래서 플러그인을 걷어내고 CalendarContract 를 직접 다루는
/// [NativeCalendarBridge] 로 옮겼다 — 조회는 원본 Events 테이블을 쓴다.
class SamsungCalendarSyncService {
  static const _calendarName = 'CoyHouseCalender';

  final CalendarEventMapping _mapping;

  SamsungCalendarSyncService({CalendarEventMapping? mapping})
    : _mapping = mapping ?? CalendarEventMapping();

  bool get _supported =>
      !kIsWeb && Platform.isAndroid && NativeCalendarBridge.isSupported;

  Future<bool> get _enabled async =>
      _supported && await DeviceSyncPrefs.isEnabled();

  /// 캘린더 권한 확보.
  ///
  /// 조회·쓰기는 전부 네이티브로 옮겼지만 권한 요청 다이얼로그는
  /// device_calendar 플러그인 것을 그대로 쓴다(이 부분은 정상 동작한다).
  Future<bool> _ensurePermission() async {
    try {
      final plugin = DeviceCalendarPlugin();
      final has = await plugin.hasPermissions();
      if (has.data == true) return true;
      final requested = await plugin.requestPermissions();
      return requested.data == true;
    } catch (e) {
      debugPrint('[SamsungCalendarSync] 권한 요청 실패: $e');
      return false;
    }
  }

  Future<String?> _ensureCalendarExists() async {
    if (!await _ensurePermission()) return null;
    final pick = pickAppCalendar(
      await NativeCalendarBridge.queryCalendars(),
      _calendarName,
      await _mapping.getCalendarId(),
    );
    for (final extra in pick.extras) {
      await NativeCalendarBridge.deleteCalendar(extra);
    }
    final id =
        pick.keep ?? await NativeCalendarBridge.ensureCalendar(_calendarName);
    if (id != null) await _mapping.setCalendarId(id);
    return id;
  }

  /// 앱이 만든 캘린더를 전부 지운다. 쌓인 사본을 한 번에 정리하는 경로.
  Future<int> deleteAppCalendars() async {
    if (!_supported || !await _ensurePermission()) return 0;
    final removed =
        await NativeCalendarBridge.deleteCalendarsByName(_calendarName);
    await _mapping.clear();
    return removed;
  }

  /// 플러그인이 실제로 보는 캘린더 목록 — 진단용.
  Future<String> describeCalendars() async {
    if (!_supported) return '안드로이드가 아닙니다';
    final buffer = StringBuffer();
    buffer.writeln('캐시된 캘린더 ID: ${await _mapping.getCalendarId() ?? '(없음)'}');
    buffer.writeln('찾는 이름: $_calendarName');
    try {
      final calendars = await NativeCalendarBridge.queryCalendars();
      buffer.writeln('전체 ${calendars.length}개:');
      for (final c in calendars) {
        final mine = c.name == _calendarName ? ' ★일치' : '';
        buffer.writeln(
          '· "${c.name}" / id=${c.id} / 계정=${c.accountName}'
          '${c.isLocal ? ' / 로컬' : ''}$mine',
        );
      }
    } catch (e) {
      buffer.writeln('조회 실패: $e');
    }
    return buffer.toString();
  }

  static bool _syncAllInProgress = false;

  Future<SamsungSyncSummary> syncAll(List<EventModel> events) async {
    final summary = SamsungSyncSummary();
    if (!await _enabled || _syncAllInProgress) return summary;
    _syncAllInProgress = true;
    try {
      final calendarId = await _ensureCalendarExists();
      if (calendarId == null) {
        summary.firstError = '캘린더 권한/생성 실패';
        return summary;
      }

      final deviceEvents = await NativeCalendarBridge.queryEvents(calendarId);
      var map = await _mapping.loadAll();
      final active = events.where((e) => !e.isProposed).toList();

      final indexed = deviceEvents
          .map(
            (e) => (
              id: e.id,
              marker: firestoreIdFromMarker(e.customAppUri),
              key: deviceEventKey(
                e.title,
                DateTime.fromMillisecondsSinceEpoch(
                  e.dtstart,
                  isUtc: e.allDay,
                ),
                allDay: e.allDay,
              ),
            ),
          )
          .toList();

      final knownKeys = active
          .map(
            (e) =>
                deviceEventKey(e.title, e.startDateTime, allDay: e.isAllDay),
          )
          .toSet();

      summary.deviceEvents = indexed.map((e) => e.id).toSet().length;
      summary.appCalendars = (await NativeCalendarBridge.queryCalendars())
          .where((c) => c.name == _calendarName)
          .length;
      summary.unmatched = indexed
          .where((e) => e.marker == null && !knownKeys.contains(e.key))
          .map((e) => e.id)
          .toSet()
          .length;

      // 1) 쌓인 중복 정리 — 같은 앱 일정의 사본은 하나만 남긴다.
      final dupIds = duplicateDeviceEventIdsToDelete(
        indexed,
        map.values.toSet(),
        knownKeys: knownKeys,
      );
      summary.duplicatesFound = dupIds.length;
      for (final id in dupIds) {
        if (await NativeCalendarBridge.deleteEvent(id)) summary.deleted++;
      }
      final doomed = dupIds.toSet();
      final liveIds = indexed
          .map((e) => e.id)
          .where((id) => !doomed.contains(id))
          .toSet();

      // 2) 기존 항목 입양 — 매핑이 유실돼도 다시 만들지 않는다. 마커 우선.
      final byMarker = <String, String>{};
      final byKey = <String, String>{};
      for (final e in indexed) {
        if (!liveIds.contains(e.id)) continue;
        if (e.marker != null) {
          byMarker.putIfAbsent(e.marker!, () => e.id);
        } else {
          byKey.putIfAbsent(e.key, () => e.id);
        }
      }

      for (final event in active) {
        final mapped = map[event.id];
        var deviceId = (mapped != null && liveIds.contains(mapped))
            ? mapped
            : null;
        deviceId ??= byMarker[event.id];
        deviceId ??= byKey[deviceEventKey(
          event.title,
          event.startDateTime,
          allDay: event.isAllDay,
        )];

        final isNew = deviceId == null;
        final error = await _write(event, calendarId, deviceId);
        if (error == null) {
          isNew ? summary.created++ : summary.updated++;
        } else {
          summary.failed++;
          summary.firstError ??= '${event.title}: $error';
        }
      }

      // 3) 스트림에서 사라진 매핑 삭제
      map = await _mapping.loadAll();
      final activeIds = active.map((e) => e.id).toSet();
      for (final staleId
          in map.keys.where((id) => !activeIds.contains(id)).toList()) {
        await syncEventDelete(staleId);
        summary.deleted++;
      }

      // 4) 전용 캘린더에 남은 고아 삭제
      final mappedIds = (await _mapping.loadAll()).values.toSet();
      for (final id in liveIds.where((id) => !mappedIds.contains(id))) {
        if (await NativeCalendarBridge.deleteEvent(id)) summary.deleted++;
      }
    } catch (e) {
      debugPrint('[SamsungCalendarSync] syncAll error: $e');
      summary.firstError ??= '$e';
    } finally {
      _syncAllInProgress = false;
    }
    return summary;
  }

  /// 성공 시 null, 실패 시 에러 메시지.
  Future<String?> _write(
    EventModel event,
    String calendarId,
    String? deviceEventId,
  ) async {
    try {
      final spec = buildDeviceEventSpec(event);
      final id = await NativeCalendarBridge.upsertEvent(
        calendarId: calendarId,
        eventId: deviceEventId,
        title: spec.title,
        description: spec.description,
        dtstart: spec.dtstart,
        dtend: spec.dtend,
        allDay: spec.allDay,
        timeZone: spec.timeZone,
        rrule: spec.rrule,
        customAppUri: coyEventMarker(event.id),
      );
      if (id == null) return '이벤트 ID를 반환하지 않음';
      await _mapping.setDeviceEventId(event.id, id);
      return null;
    } catch (e) {
      debugPrint('[SamsungCalendarSync] write error: $e');
      return '$e';
    }
  }

  Future<String?> syncEventCreate(EventModel event) async {
    if (!await _enabled) return null;
    final calendarId = await _ensureCalendarExists();
    if (calendarId == null) return '캘린더 권한/생성 실패';
    return _write(event, calendarId, null);
  }

  Future<String?> syncEventUpdate(EventModel event) async {
    if (!await _enabled) return null;
    final calendarId = await _ensureCalendarExists();
    if (calendarId == null) return '캘린더 권한/생성 실패';
    return _write(event, calendarId, await _mapping.getDeviceEventId(event.id));
  }

  Future<void> syncEventDelete(String eventId) async {
    if (!_supported) return;
    try {
      final deviceEventId = await _mapping.getDeviceEventId(eventId);
      if (deviceEventId == null) return;
      await NativeCalendarBridge.deleteEvent(deviceEventId);
      await _mapping.removeDeviceEventId(eventId);
    } catch (e) {
      debugPrint('[SamsungCalendarSync] delete error: $e');
    }
  }
}
