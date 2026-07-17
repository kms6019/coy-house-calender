import '../models/event_model.dart';
import '../models/wish_model.dart';
import 'event_utils.dart';

class MonthlyReport {
  final int totalEvents;
  final int myEvents;
  final int partnerEvents;
  final int allDayEvents;
  final String? topIcon;
  final int wishesDone;
  final int wishesTotal;

  const MonthlyReport({
    required this.totalEvents,
    required this.myEvents,
    required this.partnerEvents,
    required this.allDayEvents,
    this.topIcon,
    required this.wishesDone,
    required this.wishesTotal,
  });
}

MonthlyReport buildMonthlyReport({
  required List<EventModel> events,
  required List<WishModel> wishes,
  required DateTime month,
  required String myUid,
}) {
  final monthStart = DateTime(month.year, month.month, 1);
  final monthEnd = DateTime(month.year, month.month + 1, 0);
  final occurrences = expandRecurringForRange(events, monthStart, monthEnd)
      .where(
        (event) =>
            event.startDateTime.year == month.year &&
            event.startDateTime.month == month.month,
      )
      .toList();

  var myEvents = 0;
  var allDayEvents = 0;
  final iconCounts = <String, int>{};

  for (final occurrence in occurrences) {
    if (occurrence.createdByUid == myUid) {
      myEvents++;
    }
    if (occurrence.isAllDay) {
      allDayEvents++;
    }

    final icon = occurrence.icon;
    if (icon != null && icon.isNotEmpty) {
      iconCounts[icon] = (iconCounts[icon] ?? 0) + 1;
    }
  }

  String? topIcon;
  var topIconCount = 0;
  for (final entry in iconCounts.entries) {
    if (entry.value > topIconCount) {
      topIcon = entry.key;
      topIconCount = entry.value;
    }
  }

  final totalEvents = occurrences.length;
  return MonthlyReport(
    totalEvents: totalEvents,
    myEvents: myEvents,
    partnerEvents: totalEvents - myEvents,
    allDayEvents: allDayEvents,
    topIcon: topIcon,
    wishesDone: wishes.where((wish) => wish.done).length,
    wishesTotal: wishes.length,
  );
}
