import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/event_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/calendar_provider.dart';
import '../../services/notification_service.dart';

class EventDetailScreen extends ConsumerWidget {
  final EventModel event;
  const EventDetailScreen({super.key, required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUid = ref.watch(authStateProvider).valueOrNull?.uid;
    final isOwner = event.createdByUid == currentUid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('일정 상세'),
        actions: [
          if (isOwner) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push('/event/edit', extra: event),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDelete(context, ref),
            ),
          ],
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: event.colorValue,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  event.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _InfoRow(
            icon: Icons.calendar_today_outlined,
            label: '날짜',
            value: DateFormat('yyyy년 M월 d일 (E)', 'ko_KR').format(event.startDateTime),
          ),
          if (!event.isAllDay) ...[
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.access_time_outlined,
              label: '시간',
              value: event.endDateTime != null
                  ? '${DateFormat('HH:mm').format(event.startDateTime)} ~ ${DateFormat('HH:mm').format(event.endDateTime!)}'
                  : DateFormat('HH:mm').format(event.startDateTime),
            ),
          ],
          if (event.isAllDay) ...[
            const SizedBox(height: 12),
            const _InfoRow(icon: Icons.wb_sunny_outlined, label: '시간', value: '종일'),
          ],
          if (event.hasAlarm) ...[
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.notifications_outlined,
              label: '알림',
              value: event.alarmMinutesBefore == 0
                  ? '시작 시'
                  : '${event.alarmMinutesBefore}분 전',
            ),
          ],
          if (event.description != null && event.description!.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            Text(event.description!),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('일정 삭제'),
        content: const Text('이 일정을 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(firestoreServiceProvider).deleteEvent(event.id);
      await NotificationService().cancelAlarm(event.id);
      if (context.mounted) context.pop();
    }
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 12),
        Text('$label  ', style: const TextStyle(color: Colors.grey)),
        Text(value),
      ],
    );
  }
}
