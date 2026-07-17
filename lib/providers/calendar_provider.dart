import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/event_model.dart';
import '../models/couple_model.dart';
import '../services/firestore_service.dart';
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

// 이벤트 변경 시 홈 위젯 자동 갱신
final widgetSyncProvider = Provider<void>((ref) {
  final events = ref.watch(eventsStreamProvider).valueOrNull;
  if (events != null) {
    WidgetService.update(events);
  }
});

// 선택된 날짜
final selectedDateProvider = StateProvider<DateTime>((ref) => DateUtils.dateOnly(DateTime.now()));

final focusedDateProvider = StateProvider<DateTime>((ref) => DateUtils.dateOnly(DateTime.now()));
