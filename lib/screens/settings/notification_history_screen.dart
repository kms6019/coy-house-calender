import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/calendar_provider.dart';
import '../../services/notification_history_service.dart';

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
    final entriesAsync = ref.watch(_notificationHistoryProvider);
    final events = ref.watch(eventsStreamProvider).valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('알림 기록')),
      body: entriesAsync.when(
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
      ),
    );
  }
}
