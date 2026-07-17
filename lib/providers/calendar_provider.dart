import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/event_model.dart';
import '../models/couple_model.dart';
import '../models/wish_model.dart';
import '../services/firestore_service.dart';
import '../services/briefing_prefs.dart';
import '../services/notification_service.dart';
import '../services/widget_service.dart';
import 'auth_provider.dart';

final firestoreServiceProvider =
    Provider<FirestoreService>((ref) => FirestoreService());

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
    WidgetService.update(events,
        anniversaries: couple?.anniversaries ?? const []);
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

  // 아침 브리핑 재스케줄 (기기 설정 기반)
  BriefingPrefs.load().then((p) {
    ns.scheduleBriefings(
      events: events,
      enabled: p.enabled,
      hour: p.hour,
      minute: p.minute,
    );
  });
});

// 선택된 날짜
final selectedDateProvider = StateProvider<DateTime>((ref) => DateUtils.dateOnly(DateTime.now()));

final focusedDateProvider = StateProvider<DateTime>((ref) => DateUtils.dateOnly(DateTime.now()));
