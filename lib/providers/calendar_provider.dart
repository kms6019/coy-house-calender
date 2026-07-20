import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/event_model.dart';
import '../models/couple_model.dart';
import '../models/korean_holiday.dart';
import '../models/wish_model.dart';
import '../services/firestore_service.dart';
import '../services/korean_holiday_service.dart';
import '../services/notification_service.dart';
import '../services/samsung_calendar_sync_service.dart';
import '../services/settings_migration.dart';
import '../services/widget_service.dart';
import 'auth_provider.dart';

final firestoreServiceProvider = Provider<FirestoreService>(
  (ref) => FirestoreService(),
);

final koreanHolidayServiceProvider = Provider<KoreanHolidayService>(
  (ref) => KoreanHolidayService.instance,
);

final koreanHolidaysProvider = FutureProvider.family<List<KoreanHoliday>, int>((
  ref,
  year,
) async {
  final enabled =
      ref.watch(currentUserModelProvider).valueOrNull?.showKoreanHolidays ?? true;
  if (!enabled) return const <KoreanHoliday>[];
  return ref.watch(koreanHolidayServiceProvider).getHolidaysForYear(year);
});

final coupleStreamProvider = StreamProvider<CoupleModel?>((ref) {
  final userAsync = ref.watch(currentUserModelProvider);
  final coupleId = userAsync.valueOrNull?.coupleId ?? '';
  if (coupleId.isEmpty) return Stream.value(null);
  return ref.watch(firestoreServiceProvider).coupleStream(coupleId);
});

final eventsStreamProvider = StreamProvider<List<EventModel>>((ref) {
  final userAsync = ref.watch(currentUserModelProvider);
  final coupleId = userAsync.valueOrNull?.coupleId ?? '';
  if (coupleId.isEmpty) return Stream.value([]);
  return ref.watch(firestoreServiceProvider).eventsStream(coupleId);
});

final wishesStreamProvider = StreamProvider<List<WishModel>>((ref) {
  final userAsync = ref.watch(currentUserModelProvider);
  final coupleId = userAsync.valueOrNull?.coupleId ?? '';
  if (coupleId.isEmpty) return Stream.value([]);
  return ref.watch(firestoreServiceProvider).wishesStream(coupleId);
});

// 이벤트/기념일 변경 시 홈 위젯 자동 갱신
final widgetSyncProvider = Provider<void>((ref) {
  final events = ref.watch(eventsStreamProvider).valueOrNull;
  final couple = ref.watch(coupleStreamProvider).valueOrNull;
  if (events != null) {
    WidgetService.update(
      events,
      anniversaries: couple?.anniversaries ?? const [],
    );
  }
});

// 이벤트 변화 시(앱 실행 포함) 알림 재스케줄 — 반복 이벤트의 다음 회차 갱신용
final alarmSyncProvider = Provider<void>((ref) {
  final events = ref.watch(eventsStreamProvider).valueOrNull;
  if (events == null) return;
  final ns = NotificationService();
  for (final event in events) {
    ns.cancelAlarm(event.id).then((_) {
      if (event.hasAlarm) ns.scheduleAlarm(event);
    });
  }

  final user = ref.watch(currentUserModelProvider).valueOrNull;
  ns.scheduleBriefings(
    events: events,
    enabled: user?.briefingEnabled ?? false,
    hour: user?.briefingHour ?? 8,
    minute: user?.briefingMinute ?? 0,
  );
});

// 커플 이벤트 전체를 기기(삼성) 캘린더에 미러 동기화 — 상대가 올린 일정 포함
final deviceCalendarSyncProvider = Provider<void>((ref) {
  final coupleId =
      ref.watch(currentUserModelProvider).valueOrNull?.coupleId ?? '';
  if (coupleId.isEmpty) return; // 로그아웃/연결 해제 시 기기 캘린더 삭제 방지
  final events = ref.watch(eventsStreamProvider).valueOrNull;
  if (events == null) return;
  SamsungCalendarSyncService().syncAll(events);
});

// 선택된 날짜
final selectedDateProvider = StateProvider<DateTime>(
  (ref) => DateUtils.dateOnly(DateTime.now()),
);

final focusedDateProvider = StateProvider<DateTime>(
  (ref) => DateUtils.dateOnly(DateTime.now()),
);

// 구버전 SharedPreferences 설정을 Firestore로 1회 승격
final settingsMigrationProvider = Provider<void>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return;
  SettingsMigrationService().runIfNeeded(uid);
});
