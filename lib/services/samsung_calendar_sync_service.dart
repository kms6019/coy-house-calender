import 'dart:io' show Platform;
import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:timezone/timezone.dart' as tz;
import '../models/event_model.dart';
import 'calendar_event_mapping.dart';
import 'device_calendar_event_builder.dart';
import 'device_sync_prefs.dart';

class SamsungSyncSummary {
  int created = 0;
  int updated = 0;
  int deleted = 0;
  int failed = 0;
  String? firstError;

  /// 진단용 — 왜 정리가 안 됐는지 화면에서 확인하기 위한 값들
  int appCalendars = 0; // CoyHouseCalender 이름의 캘린더 개수 (2개 이상이면 문제)
  int deviceEvents = 0; // 전용 캘린더에서 읽어들인 기기 이벤트 수
  int duplicatesFound = 0;
  int unmatched = 0; // 마커도 지문도 앱 일정과 안 맞아 건드리지 않은 항목

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
///
/// 반복 일정은 Instances 조회가 회차마다 행을 돌려주므로, 먼저 id로 중복을 없앤다.
List<String> duplicateDeviceEventIdsToDelete(
  List<DeviceEventRef> events,
  Set<String> mappedIds, {
  Set<String> knownKeys = const {},
}) {
  final seen = <String>{};
  final groups = <String, List<String>>{};
  for (final e in events) {
    if (!seen.add(e.id)) continue; // 같은 이벤트의 다른 회차
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

  Future<bool> get _enabled async =>
      _supported && await DeviceSyncPrefs.isEnabled();

  /// 이 기기에서 방금 쓴 이벤트를 다시 읽을 수 있는지 실제로 확인한다.
  ///
  /// 조회가 "성공 + 빈 목록"을 돌려주는 기기가 있어서, 조회 결과만 보고
  /// 생성 여부를 정하면 사본이 무한히 쌓인다. 탐침 이벤트를 하나 만들어
  /// 되읽어 보고, 못 읽으면 이 기기에서는 생성을 하지 않는다.
  Future<bool> _verifyReadable(String calendarId) async {
    final now = DateTime.now();
    final start = tz.TZDateTime.from(
      DateTime(now.year, now.month, now.day).add(const Duration(days: 1)),
      tz.local,
    );
    final probe = Event(
      calendarId,
      title: '__coyhouse_probe__',
      start: start,
      end: start.add(const Duration(minutes: 30)),
    );
    final created = await _plugin.createOrUpdateEvent(probe);
    final probeId = created?.data;
    if (created == null || created.hasErrors || probeId == null) {
      debugPrint('[SamsungCalendarSync] 탐침 생성 실패 — 읽기 검증 불가');
      return false;
    }
    try {
      final events = await _retrieveAllDeviceEvents(calendarId);
      final visible =
          events != null && events.any((e) => e.eventId == probeId);
      if (!visible) {
        debugPrint('[SamsungCalendarSync] 탐침을 되읽지 못함 — 조회 신뢰 불가');
      }
      return visible;
    } finally {
      await _plugin.deleteEvent(calendarId, probeId);
    }
  }

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
    if (!await _enabled) return null;
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
    if (!await _enabled) return null;
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

  /// 전용 캘린더의 이벤트 전체. 조회에 실패하면 null — 이때는 아무것도 만들지 않는다.
  ///
  /// 예전에는 조회가 빈 목록을 돌려주면 "기기에 아무것도 없다"고 믿고 전부 새로
  /// 만들었다. 쿼리가 잠깐 실패하거나 범위 밖으로 잡히면 동기화 한 번에 사본이
  /// 하나씩 늘었고, 그게 쌓여 같은 일정이 수십 개가 됐다.
  Future<List<Event>?> _retrieveAllDeviceEvents(String calendarId) async {
    // 기간 미지정 시 플러그인이 끝을 Long.MAX_VALUE로 잡아 Instances 쿼리가
    // 깨질 수 있어 명시적 범위를 함께 전달한다.
    final now = DateTime.now();
    final result = await _plugin.retrieveEvents(
      calendarId,
      RetrieveEventsParams(
        startDate: DateTime(now.year - 5),
        endDate: DateTime(now.year + 5),
      ),
    );
    if (result.hasErrors || result.data == null) {
      debugPrint(
        '[SamsungCalendarSync] retrieveEvents error: ${_formatErrors(result.errors)}',
      );
      return null;
    }
    return result.data!;
  }

  /// 플러그인이 실제로 보는 캘린더 목록. 앱이 기기 캘린더를 왜 못 찾는지
  /// 눈으로 확인하기 위한 진단용.
  Future<String> describeCalendars() async {
    if (!_supported) return '안드로이드가 아닙니다';
    final buffer = StringBuffer();
    final cached = await _mapping.getCalendarId();
    buffer.writeln('캐시된 캘린더 ID: ${cached ?? '(없음)'}');
    buffer.writeln('찾는 이름: $_calendarName');

    final result = await _plugin.retrieveCalendars();
    if (result.hasErrors) {
      buffer.writeln('조회 오류: ${_formatErrors(result.errors)}');
    }
    final calendars = result.data;
    if (calendars == null) {
      buffer.writeln('조회 결과 없음(null)');
      return buffer.toString();
    }

    buffer.writeln('전체 ${calendars.length}개:');
    for (final c in calendars) {
      final mine = c.name == _calendarName ? ' ★일치' : '';
      buffer.writeln(
        '· "${c.name}" / id=${c.id} / 계정=${c.accountName}'
        '${c.isReadOnly == true ? ' / 읽기전용' : ''}$mine',
      );
    }
    return buffer.toString();
  }

  /// CoyHouseCalender 이름의 캘린더 개수. 2개 이상이면 한쪽만 청소되어
  /// 중복이 계속 보일 수 있다 — 진단용.
  Future<int> _countAppCalendars() async {
    final result = await _plugin.retrieveCalendars();
    if (result.hasErrors || result.data == null) return 0;
    return result.data!.where((c) => c.name == _calendarName).length;
  }

  Future<int> _deleteDeviceEvents(
    String calendarId,
    Iterable<String> ids,
  ) async {
    var deleted = 0;
    for (final id in ids) {
      final del = await _plugin.deleteEvent(calendarId, id);
      if (del.hasErrors) {
        debugPrint(
          '[SamsungCalendarSync] delete error: ${_formatErrors(del.errors)}',
        );
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
    if (!await _enabled || _syncAllInProgress) return summary;
    _syncAllInProgress = true;
    try {
      final calendarId = await _ensureCalendarExists();
      if (calendarId == null) {
        summary.firstError = '캘린더 권한/생성 실패';
        return summary;
      }

      // 기기 상태를 못 읽으면 아무것도 만들지 않는다. 모르는 채로 생성하면
      // 이미 있는 일정을 또 만들어 중복이 쌓인다.
      final deviceEvents = await _retrieveAllDeviceEvents(calendarId);
      if (deviceEvents == null) {
        summary.firstError = '기기 캘린더 조회 실패 — 중복 방지를 위해 동기화를 건너뜀';
        return summary;
      }

      var map = await _mapping.loadAll();
      final active = events.where((e) => !e.isProposed).toList();

      // 조회가 "성공 + 빈 목록"을 주는 기기가 있다. 매핑이 비어 있으면 이 조건만으로는
      // 구분이 안 되므로(초기화 직후 등), 탐침을 써서 조회 자체를 신뢰할 수 있는지
      // 직접 확인한다. 못 믿으면 아무것도 만들지 않는다 — 만들면 사본만 쌓인다.
      if (deviceEvents.isEmpty && !await _verifyReadable(calendarId)) {
        summary.firstError =
            '이 기기에서는 캘린더 조회가 동작하지 않습니다(방금 만든 일정도 못 읽음). '
            '중복이 쌓이므로 동기화를 중단했습니다. '
            '설정에서 "기기 캘린더 동기화"를 끄고, 삼성캘린더 앱에서 '
            'CoyHouseCalender 캘린더를 직접 삭제하세요.';
        return summary;
      }

      final indexed = deviceEvents
          .where((e) => e.eventId != null)
          .map(
            (e) => (
              id: e.eventId!,
              marker: firestoreIdFromMarker(e.url?.toString()),
              key: deviceEventKey(
                e.title,
                e.start,
                allDay: e.allDay ?? false,
              ),
            ),
          )
          .toList();

      // 마커가 없는 옛 항목은 앱이 실제로 가진 일정과 지문이 맞을 때만 손댄다.
      final knownKeys = active
          .map(
            (e) => deviceEventKey(
              e.title,
              e.startDateTime,
              allDay: e.isAllDay,
            ),
          )
          .toSet();

      summary.deviceEvents = indexed.map((e) => e.id).toSet().length;
      summary.appCalendars = await _countAppCalendars();
      summary.unmatched = indexed
          .where((e) => e.marker == null && !knownKeys.contains(e.key))
          .map((e) => e.id)
          .toSet()
          .length;

      // 1) 이미 쌓인 중복 정리 — 같은 앱 일정의 사본은 하나만 남긴다.
      final dupIds = duplicateDeviceEventIdsToDelete(
        indexed,
        map.values.toSet(),
        knownKeys: knownKeys,
      );
      summary.duplicatesFound = dupIds.length;
      if (dupIds.isNotEmpty) {
        debugPrint('[SamsungCalendarSync] 중복 ${dupIds.length}건 정리');
        summary.deleted += await _deleteDeviceEvents(calendarId, dupIds);
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

        final String? error;
        if (deviceId != null) {
          if (mapped != deviceId) {
            await _mapping.setDeviceEventId(event.id, deviceId);
          }
          error = await syncEventUpdate(event);
          if (error == null) summary.updated++;
        } else {
          if (mapped != null) await _mapping.removeDeviceEventId(event.id);
          error = await syncEventCreate(event);
          if (error == null) summary.created++;
        }
        if (error != null) {
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

      // 4) 전용 캘린더에 남은 고아(매핑에 없는 항목) 삭제
      final mappedIds = (await _mapping.loadAll()).values.toSet();
      final orphans = liveIds.where((id) => !mappedIds.contains(id));
      summary.deleted += await _deleteDeviceEvents(calendarId, orphans);
    } catch (e) {
      debugPrint('[SamsungCalendarSync] syncAll error: $e');
      summary.firstError ??= '$e';
    } finally {
      _syncAllInProgress = false;
    }
    return summary;
  }

  /// 전용 캘린더를 통째로 지우고 다시 만든 뒤 한 번만 동기화한다.
  ///
  /// 기기 이벤트 조회를 신뢰할 수 없을 때(성공했는데 빈 목록) 쌓인 사본을
  /// 확실히 없애는 방법. CoyHouseCalender 는 앱이 만든 전용 캘린더라 통째로
  /// 지워도 사용자의 다른 캘린더에는 영향이 없다.
  ///
  /// 같은 이름의 캘린더가 여러 개 생겼을 경우도 전부 지운다.
  Future<SamsungSyncSummary> resetCalendar(List<EventModel> events) async {
    final summary = SamsungSyncSummary();
    if (!_supported) return summary;
    try {
      final result = await _plugin.retrieveCalendars();
      if (result.hasErrors || result.data == null) {
        summary.firstError = '캘린더 목록 조회 실패: ${_formatErrors(result.errors)}';
        return summary;
      }
      final targets =
          result.data!.where((c) => c.name == _calendarName).toList();
      summary.appCalendars = targets.length;

      // 이름으로 하나도 못 찾았는데 캐시된 캘린더 ID가 있으면, 플러그인이 앱
      // 캘린더를 못 보고 있다는 뜻이다. 이 상태에서 "지울 게 없으니 새로 만들자"로
      // 넘어가면 캘린더가 하나 더 생긴다(실제로 4개까지 늘었다).
      if (targets.isEmpty) {
        final cached = await _mapping.getCalendarId();
        if (cached != null) {
          final del = await _plugin.deleteCalendar(cached);
          if (del.hasErrors || del.data != true) {
            summary.failed++;
            summary.firstError =
                '앱이 기기 캘린더를 인식하지 못합니다(이름으로 조회 0개). '
                '새로 만들지 않았습니다 — 삼성캘린더 앱에서 CoyHouseCalender 캘린더를 '
                '직접 모두 삭제한 뒤, 설정에서 "기기 캘린더 동기화"를 다시 켜세요.';
            return summary;
          }
          summary.deleted++;
        } else {
          summary.firstError =
              '지울 캘린더를 찾지 못했습니다. 삼성캘린더 앱에서 직접 삭제해 주세요.';
          return summary;
        }
      }

      for (final calendar in targets) {
        final id = calendar.id;
        if (id == null) continue;
        final del = await _plugin.deleteCalendar(id);
        // data == true 여야 실제로 지워진 것이다. 오류가 없다는 것만으로는 부족하다.
        if (del.hasErrors || del.data != true) {
          debugPrint(
            '[SamsungCalendarSync] deleteCalendar 실패: ${_formatErrors(del.errors)}',
          );
          summary.failed++;
        } else {
          summary.deleted++;
        }
      }

      // 삭제가 실제로 됐는지 이름으로 재확인한다. 남아 있으면 절대 다시 만들지
      // 않는다 — 예전에는 여기서 사본을 매번 16개씩 더 얹었다.
      final after = await _plugin.retrieveCalendars();
      final remaining = (after.hasErrors || after.data == null)
          ? -1
          : after.data!.where((c) => c.name == _calendarName).length;
      if (remaining != 0) {
        summary.firstError =
            '기기에서 CoyHouseCalender 캘린더를 삭제하지 못했습니다'
            '${remaining > 0 ? ' ($remaining개 남음)' : ''}. '
            '다시 만들지 않았습니다 — 삼성캘린더 앱에서 직접 삭제한 뒤 다시 시도하세요.';
        return summary;
      }

      await _mapping.clear();
    } catch (e) {
      debugPrint('[SamsungCalendarSync] resetCalendar error: $e');
      summary.firstError ??= '$e';
      return summary;
    }

    // 새 캘린더에 처음부터 다시 만든다.
    final rebuilt = await syncAll(events);
    summary.created = rebuilt.created;
    summary.updated = rebuilt.updated;
    summary.deviceEvents = rebuilt.deviceEvents;
    summary.failed += rebuilt.failed;
    summary.firstError ??= rebuilt.firstError;
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
