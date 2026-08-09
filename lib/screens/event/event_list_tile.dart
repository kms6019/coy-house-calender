import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/event_model.dart';
import '../../utils/event_utils.dart';
import 'event_detail_screen.dart' show EventDetailArgs;

class EventListTile extends StatelessWidget {
  final EventModel event;
  const EventListTile({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final timeFmt = DateFormat('HH:mm');
    final String timeText;
    if (event.isAllDay) {
      timeText = '종일';
    } else if (event.endDateTime != null) {
      timeText =
          '${timeFmt.format(event.startDateTime)} ~ ${timeFmt.format(event.endDateTime!)}';
    } else {
      timeText = timeFmt.format(event.startDateTime);
    }

    return Card(
      color: colors.surfaceContainerHigh.withValues(alpha: 0.72),
      child: ListTile(
        leading: Container(
          width: 10,
          height: 42,
          decoration: BoxDecoration(
            color: event.colorValue,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        title: Text(
          '${event.icon != null ? '${event.icon} ${event.title}' : event.title}${event.isShared ? '  ♥' : ''}${event.isProposed ? '  ✉' : ''}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          '${event.isProposed ? '제안 · ' : ''}$timeText',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (event.repeat != RepeatRule.none)
              Icon(Icons.repeat, size: 16, color: colors.onSurfaceVariant),
            if (event.hasAlarm)
              Padding(
                padding: const EdgeInsets.only(left: 5),
                child: Icon(
                  Icons.notifications_outlined,
                  size: 16,
                  color: colors.onSurfaceVariant,
                ),
              ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
          ],
        ),
        onTap: () => context.push(
          '/event/detail',
          extra: EventDetailArgs(
            event: event,
            occurrenceDate: calendarDateKey(event.startDateTime),
          ),
        ),
      ),
    );
  }
}
