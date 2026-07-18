import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/event_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/calendar_provider.dart';
import '../../services/notification_service.dart';
import '../../services/samsung_calendar_sync_service.dart';
import '../../utils/event_utils.dart';

class EventDetailArgs {
  final EventModel event; // occurrence 복사본 (표시용)
  final DateTime occurrenceDate; // 열어본 회차 날짜 (자정)
  const EventDetailArgs({required this.event, required this.occurrenceDate});
}

class EventDetailScreen extends ConsumerWidget {
  final EventModel event;
  final DateTime? occurrenceDate;
  const EventDetailScreen({super.key, required this.event, this.occurrenceDate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUid = ref.watch(authStateProvider).valueOrNull?.uid;
    // 반복 이벤트의 event는 occurrence 복사본 — 수정/삭제는 마스터 기준
    final master = ref
            .watch(eventsStreamProvider)
            .valueOrNull
            ?.firstWhere((e) => e.id == event.id, orElse: () => event) ??
        event;
    final isOwner = event.createdByUid == currentUid || event.createdByUid.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('일정 상세'),
        actions: [
          if (isOwner) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push('/event/edit', extra: master),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDelete(context, ref, master),
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
                  event.icon != null
                      ? '${event.icon} ${event.title}'
                      : event.title,
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
          if (master.repeat != RepeatRule.none) ...[
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.repeat,
              label: '반복',
              value: _repeatText(master),
            ),
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
          if (event.isShared) ...[
            const SizedBox(height: 12),
            const Row(
              children: [
                Icon(Icons.favorite, size: 20, color: Colors.pink),
                SizedBox(width: 12),
                Text('함께하는 일정'),
              ],
            ),
          ],
          if (event.isProposed) ...[
            const SizedBox(height: 12),
            const Row(
              children: [
                Icon(Icons.send_outlined, size: 20, color: Colors.grey),
                SizedBox(width: 12),
                Text('제안된 일정'),
              ],
            ),
          ],
          if (event.description != null && event.description!.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            Text(event.description!),
          ],
          if (master.isProposed &&
              currentUid != null &&
              master.createdByUid != currentUid) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      await ref.read(firestoreServiceProvider).updateEvent(
                            master.copyWith(
                              status: 'confirmed',
                              updatedAt: DateTime.now(),
                            ),
                            editorUid: currentUid,
                          );
                      if (context.mounted) context.pop();
                    },
                    child: const Text('수락'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _confirmReject(context, ref, master),
                    child: const Text('거절'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _repeatText(EventModel master) {
    const labels = {
      RepeatRule.daily: '매일',
      RepeatRule.weekly: '매주',
      RepeatRule.monthly: '매월',
      RepeatRule.yearly: '매년',
    };
    final base = '${labels[master.repeat]} 반복';
    if (master.repeatUntil == null) return base;
    return '$base · ${DateFormat('yyyy.MM.dd').format(master.repeatUntil!)}까지';
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, EventModel master) async {
    if (master.repeat == RepeatRule.none) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('일정 삭제'),
          content: const Text('이 일정을 삭제하시겠습니까?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('취소')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('삭제'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await _deleteAll(context, ref, master);
      return;
    }

    // 반복 이벤트: 이 회차만 / 전체
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('반복 일정 삭제'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'one'),
            child: const Text('이 일정만 삭제'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'all'),
            child: const Text('모든 반복 일정 삭제'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
        ],
      ),
    );
    if (choice == null) return;

    if (choice == 'all') {
      await _deleteAll(context, ref, master);
      return;
    }

    // 이 회차만: excludedDates에 추가 (삼성캘린더 미반영 — v1 한계)
    final day =
        calendarDateKey(occurrenceDate ?? event.startDateTime);
    final updated = master.copyWithRepeat(
      repeat: master.repeat,
      repeatUntil: master.repeatUntil,
      excludedDates: {...master.excludedDates, day}.toList(),
    );
    await ref.read(firestoreServiceProvider).updateEvent(
          updated,
          editorUid: ref.read(authStateProvider).valueOrNull?.uid,
        );
    // 다음 알림이 이 회차였을 수 있으니 재스케줄
    await NotificationService().cancelAlarm(master.id);
    if (master.hasAlarm) await NotificationService().scheduleAlarm(updated);
    if (context.mounted) context.pop();
  }

  Future<void> _deleteAll(
      BuildContext context, WidgetRef ref, EventModel master) async {
    await ref.read(firestoreServiceProvider).deleteEvent(master.id);
    await NotificationService().cancelAlarm(master.id);
    await SamsungCalendarSyncService().syncEventDelete(master.id);
    if (context.mounted) context.pop();
  }

  Future<void> _confirmReject(
      BuildContext context, WidgetRef ref, EventModel master) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('제안 거절'),
        content: const Text('이 제안을 거절하고 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('거절'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(firestoreServiceProvider).deleteEvent(master.id);
    if (context.mounted) context.pop();
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
