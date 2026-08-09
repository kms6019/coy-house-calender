import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/event_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/calendar_provider.dart';
import '../../services/alarm_history_service.dart';
import '../../services/notification_history_service.dart';
import '../../utils/event_utils.dart';
import '../../widgets/app_surface.dart';

final _notificationHistoryProvider =
    StreamProvider<List<NotificationHistoryEntry>>((ref) {
      final uid = ref.watch(authStateProvider).valueOrNull?.uid;
      if (uid == null) return Stream.value(const []);
      return NotificationHistoryService().streamFor(uid);
    });

final _alarmHistoryProvider = StreamProvider<List<AlarmRecord>>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value(const []);
  return AlarmHistoryService().stream(uid);
});

class NotificationHistoryScreen extends ConsumerWidget {
  const NotificationHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('알림 기록'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '일정 알람'),
              Tab(text: '파트너 알림'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_PastAlarmList(), _PartnerNotificationList()],
        ),
      ),
    );
  }
}

class _PastAlarmList extends ConsumerWidget {
  const _PastAlarmList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordsAsync = ref.watch(_alarmHistoryProvider);

    return recordsAsync.when(
      data: (records) {
        final now = DateTime.now();
        // 아직 안 울린 예약분은 제외 — 시각이 지난 것만 "울린 알람"으로 본다
        final alarms = records.where((r) => !r.alarmAt.isAfter(now)).toList();
        if (alarms.isEmpty) {
          return const AppEmptyState(
            icon: Icons.alarm_off_outlined,
            title: '아직 울린 알람이 없습니다',
            message: '일정 알람이 울리면 이곳에서 다시 볼 수 있어요.',
          );
        }
        return AppPageBody(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          child: ListView.separated(
            itemCount: alarms.length,
            separatorBuilder: (_, _) => const SizedBox(height: 9),
            itemBuilder: (context, index) {
              final alarm = alarms[index];
              final alarmFormat = DateFormat('M/d HH:mm');
              return Card(
                child: ListTile(
                  leading: const AppIconBadge(
                    icon: Icons.alarm_outlined,
                    emphasized: true,
                  ),
                  title: Text(
                    alarm.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${alarmFormat.format(alarm.alarmAt)} 알림'
                    ' · 일정 ${alarmFormat.format(alarm.occurrenceStart)}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    final day = calendarDateKey(alarm.occurrenceStart);
                    ref.read(focusedDateProvider.notifier).state = DateTime(
                      day.year,
                      day.month,
                      1,
                    );
                    ref.read(selectedDateProvider.notifier).state = day;
                    context.go('/calendar');
                  },
                ),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const Center(child: Text('불러오지 못했습니다')),
    );
  }
}

class _PartnerNotificationList extends ConsumerWidget {
  const _PartnerNotificationList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(_notificationHistoryProvider);
    final events =
        ref.watch(eventsStreamProvider).valueOrNull ?? <EventModel>[];

    return entriesAsync.when(
      data: (entries) {
        if (entries.isEmpty) {
          return const AppEmptyState(
            icon: Icons.favorite_border,
            title: '아직 받은 알림이 없습니다',
            message: '파트너가 일정을 등록하거나 제안하면 여기에 모아 드려요.',
          );
        }
        return AppPageBody(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          child: ListView.separated(
            itemCount: entries.length,
            separatorBuilder: (_, _) => const SizedBox(height: 9),
            itemBuilder: (context, index) {
              final entry = entries[index];
              final colors = Theme.of(context).colorScheme;
              return Card(
                child: ListTile(
                  leading: const AppIconBadge(
                    icon: Icons.favorite_outline,
                    emphasized: true,
                  ),
                  title: Text(
                    entry.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(entry.body),
                  trailing: entry.receivedAt != null
                      ? Text(
                          DateFormat('M/d HH:mm').format(entry.receivedAt!),
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.onSurfaceVariant,
                          ),
                        )
                      : null,
                  onTap: () {
                    final event = events
                        .where((e) => e.id == entry.eventId)
                        .firstOrNull;
                    if (event == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('삭제된 일정입니다')),
                      );
                      return;
                    }
                    context.push('/event/detail', extra: event);
                  },
                ),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const Center(child: Text('불러오지 못했습니다')),
    );
  }
}
