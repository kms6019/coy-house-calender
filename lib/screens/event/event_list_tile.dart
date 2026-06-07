import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/event_model.dart';

class EventListTile extends StatelessWidget {
  final EventModel event;
  const EventListTile({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final timeFmt = DateFormat('HH:mm');
    final String timeText;
    if (event.isAllDay) {
      timeText = '종일';
    } else if (event.endDateTime != null) {
      timeText = '${timeFmt.format(event.startDateTime)} ~ ${timeFmt.format(event.endDateTime!)}';
    } else {
      timeText = timeFmt.format(event.startDateTime);
    }

    return ListTile(
      leading: Container(
        width: 12,
        height: 12,
        margin: const EdgeInsets.only(top: 4),
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
