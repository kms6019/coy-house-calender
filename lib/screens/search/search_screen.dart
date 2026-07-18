import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/event_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/calendar_provider.dart';
import '../../utils/event_utils.dart';
import '../../utils/search_utils.dart';
import '../event/event_detail_screen.dart' show EventDetailArgs;

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _queryCtrl = TextEditingController();
  SearchFilter _filter = SearchFilter.all;

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(eventsStreamProvider);
    final myUid = ref.watch(authStateProvider).valueOrNull?.uid ?? '';
    final query = _queryCtrl.text.trim();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: TextField(
          controller: _queryCtrl,
          autofocus: true,
          cursorColor: Colors.white,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: '일정 검색',
            hintStyle: const TextStyle(color: Colors.white70),
            border: InputBorder.none,
            suffixIcon: _queryCtrl.text.isNotEmpty
                ? IconButton(
                    tooltip: '검색어 지우기',
                    onPressed: () {
                      _queryCtrl.clear();
                      setState(() {});
                    },
                    icon: const Icon(Icons.clear, color: Colors.white),
                  )
                : null,
          ),
          onChanged: (_) => setState(() {}),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _filterChip('전체', SearchFilter.all),
                const SizedBox(width: 8),
                _filterChip('나', SearchFilter.mine),
                const SizedBox(width: 8),
                _filterChip('상대', SearchFilter.partner),
              ],
            ),
          ),
          Expanded(
            child: _buildResults(
              eventsAsync: eventsAsync,
              query: query,
              myUid: myUid,
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, SearchFilter filter) {
    return ChoiceChip(
      label: Text(label),
      selected: _filter == filter,
      onSelected: (selected) {
        if (!selected) return;
        setState(() => _filter = filter);
      },
    );
  }

  Widget _buildResults({
    required AsyncValue<List<EventModel>> eventsAsync,
    required String query,
    required String myUid,
  }) {
    if (query.isEmpty) {
      return const Center(child: Text('제목이나 메모로 검색하세요'));
    }

    return eventsAsync.when(
      data: (events) {
        final results = searchEvents(
          events: events,
          query: query,
          filter: _filter,
          myUid: myUid,
        );

        if (results.isEmpty) {
          return const Center(child: Text('검색 결과가 없습니다'));
        }

        return ListView.builder(
          itemCount: results.length,
          itemBuilder: (context, index) {
            final event = results[index];
            final title = event.icon?.isNotEmpty == true
                ? '${event.icon} ${event.title}'
                : event.title;
            final repeatSuffix =
                event.repeat != RepeatRule.none ? ' · 반복' : '';

            return ListTile(
              leading: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: event.colorValue,
                  shape: BoxShape.circle,
                ),
              ),
              title: Text(title),
              subtitle: Text(
                '${DateFormat('yyyy.MM.dd (E)', 'ko_KR').format(event.startDateTime)}$repeatSuffix',
              ),
              onTap: () => context.push(
                '/event/detail',
                extra: EventDetailArgs(
                  event: event,
                  occurrenceDate: calendarDateKey(event.startDateTime),
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const Center(child: Text('일정을 불러오지 못했습니다')),
    );
  }
}
