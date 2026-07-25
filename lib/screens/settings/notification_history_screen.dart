import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/event_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/calendar_provider.dart';
import '../../services/notification_history_service.dart';
import '../../utils/alarm_history_utils.dart';
import '../../utils/event_utils.dart';

final _notificationHistoryProvider =
    StreamProvider<List<NotificationHistoryEntry>>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value(const []);
  return NotificationHistoryService().streamFor(uid);
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
          children: [
            _PastAlarmList(),
            _PartnerNotificationList(),
          ],
        ),
      ),
    );
  }
}

class _PastAlarmList extends ConsumerWidget {
  const _PastAlarmList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(eventsStreamProvider);

    return eventsAsync.when(
      data: (events) {
        final alarms = pastAlarms(events, DateTime.now());
        if (alarms.isEmpty) {
          return const Center(child: Text('지난 30일간 울린 알람이 없습니다'));
        }
        return ListView.separated(
          itemCount: alarms.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final alarm = alarms[index];
            final alarmFormat = DateFormat('M/d HH:mm');
            return ListTile(
              title: Text(alarm.event.title),
              subtitle: Text(
                '${alarmFormat.format(alarm.alarmAt)} 알림'
                ' · 일정 ${alarmFormat.format(alarm.event.startDateTime)}',
              ),
              onTap: () {
                final day = calendarDateKey(alarm.event.startDateTime);
                ref.read(focusedDateProvider.notifier).state =
                    DateTime(day.year, day.month, 1);
                ref.read(selectedDateProvider.notifier).state = day;
                context.go('/calendar');
              },
            );
          },
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
    final events = ref.watch(eventsStreamProvider).valueOrNull ?? <EventModel>[];

    return entriesAsync.when(
      data: (entries) {
        if (entries.isEmpty) {
          return const Center(child: Text('아직 받은 알림이 없습니다'));
        }
        return ListView.separated(
          itemCount: entries.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final entry = entries[index];
            return ListTile(
              title: Text(entry.title),
              subtitle: Text(entry.body),
              trailing: entry.receivedAt != null
                  ? Text(
                      DateFormat('M/d HH:mm').format(entry.receivedAt!),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    )
                  : null,
              onTap: () {
                final event =
                    events.where((e) => e.id == entry.eventId).firstOrNull;
                if (event == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('삭제된 일정입니다')),
                  );
                  return;
                }
                context.push('/event/detail', extra: event);
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const Center(child: Text('불러오지 못했습니다')),
    );
  }
}
