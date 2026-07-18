import 'package:coy_house_calender/models/event_model.dart';

enum SearchFilter { all, mine, partner }

List<EventModel> searchEvents({
  required List<EventModel> events,
  required String query,
  required SearchFilter filter,
  required String myUid,
}) {
  final normalizedQuery = query.trim().toLowerCase();
  if (normalizedQuery.isEmpty) {
    return const <EventModel>[];
  }

  final matches = events.where((event) {
    final matchesFilter = switch (filter) {
      SearchFilter.all => true,
      SearchFilter.mine => event.createdByUid == myUid,
      SearchFilter.partner => event.createdByUid != myUid,
    };
    if (!matchesFilter) {
      return false;
    }

    final matchesTitle = event.title.toLowerCase().contains(normalizedQuery);
    final matchesDescription =
        event.description?.toLowerCase().contains(normalizedQuery) ?? false;
    return matchesTitle || matchesDescription;
  }).toList();

  matches.sort(
    (first, second) => second.startDateTime.compareTo(first.startDateTime),
  );
  return matches;
}
