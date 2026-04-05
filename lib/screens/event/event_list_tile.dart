import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/event_model.dart';

class EventListTile extends StatelessWidget {
  final EventModel event;
  const EventListTile({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final timeText = event.isAllDay
        ? '종일'
        : DateFormat('HH:mm').format(event.startDateTime);

    return ListTile(
      leading: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: event.colorValue,
          shape: BoxShape.circle,
        ),
      ),
      title: Text(event.title),
      subtitle: Text(timeText, style: const TextStyle(fontSize: 12)),
      trailing: event.hasAlarm
          ? Icon(Icons.notifications_outlined, size: 16, color: Colors.grey[500])
          : null,
      onTap: () => context.push('/event/detail', extra: event),
    );
  }
}
