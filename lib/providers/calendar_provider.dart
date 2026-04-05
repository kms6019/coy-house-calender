import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/event_model.dart';
import '../models/couple_model.dart';
import '../services/firestore_service.dart';
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

// 날짜별 이벤트 맵 (table_calendar용)
final eventsByDateProvider = Provider<Map<DateTime, List<EventModel>>>((ref) {
  final events = ref.watch(eventsStreamProvider).valueOrNull ?? [];
  final map = <DateTime, List<EventModel>>{};
  for (final event in events) {
    final day = DateUtils.dateOnly(event.startDateTime);
    map.putIfAbsent(day, () => []).add(event);
  }
  return map;
});

// 선택된 날짜
final selectedDateProvider = StateProvider<DateTime>((ref) => DateUtils.dateOnly(DateTime.now()));

// 선택 날짜의 이벤트 목록
final selectedDayEventsProvider = Provider<List<EventModel>>((ref) {
  final selected = ref.watch(selectedDateProvider);
  final map = ref.watch(eventsByDateProvider);
  return map[selected] ?? [];
});
