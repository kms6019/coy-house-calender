import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/event_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/calendar_provider.dart';
import '../../utils/event_utils.dart';
import '../../utils/search_utils.dart';
import '../../widgets/app_surface.dart';
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final eventsAsync = ref.watch(eventsStreamProvider);
    final myUid = ref.watch(authStateProvider).valueOrNull?.uid ?? '';
    final query = _queryCtrl.text.trim();

    return Scaffold(
      appBar: AppBar(title: const Text('일정 검색')),
      body: AppPageBody(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        child: Column(
          children: [
            TextField(
              controller: _queryCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: '제목이나 메모로 검색',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _queryCtrl.text.isNotEmpty
                    ? IconButton(
                        tooltip: '검색어 지우기',
                        onPressed: () {
                          _queryCtrl.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close),
                      )
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                children: [
                  _filterChip('전체', SearchFilter.all),
                  _filterChip('내 일정', SearchFilter.mine),
                  _filterChip('상대 일정', SearchFilter.partner),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Divider(color: colors.outlineVariant.withValues(alpha: 0.5)),
            const SizedBox(height: 4),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: _buildResults(
                  key: ValueKey('${_filter.name}:$query'),
                  eventsAsync: eventsAsync,
                  query: query,
                  myUid: myUid,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, SearchFilter filter) {
    return ChoiceChip(
      label: Text(label),
      selected: _filter == filter,
      avatar: _filter == filter ? const Icon(Icons.check, size: 17) : null,
      onSelected: (selected) {
        if (!selected) return;
        setState(() => _filter = filter);
      },
    );
  }

  Widget _buildResults({
    required Key key,
    required AsyncValue<List<EventModel>> eventsAsync,
    required String query,
    required String myUid,
  }) {
    if (query.isEmpty) {
      return AppEmptyState(
        key: key,
        icon: Icons.manage_search_outlined,
        title: '무엇을 찾고 있나요?',
        message: '일정 제목이나 메모에 있는 단어를 입력해 보세요.',
      );
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
          return AppEmptyState(
            key: key,
            icon: Icons.search_off_outlined,
            title: '검색 결과가 없습니다',
            message: '다른 검색어나 필터로 다시 찾아보세요.',
          );
        }

        return ListView.separated(
          key: key,
          padding: const EdgeInsets.only(top: 4, bottom: 20),
          itemCount: results.length,
          separatorBuilder: (_, _) => const SizedBox(height: 9),
          itemBuilder: (context, index) {
            final event = results[index];
            final title = event.icon?.isNotEmpty == true
                ? '${event.icon} ${event.title}'
                : event.title;
            final repeatSuffix = event.repeat != RepeatRule.none ? ' · 반복' : '';
            final theme = Theme.of(context);
            final colors = theme.colorScheme;

            return Card(
              child: ListTile(
                leading: Container(
                  width: 9,
                  height: 42,
                  decoration: BoxDecoration(
                    color: event.colorValue,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                title: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  '${DateFormat('yyyy.MM.dd (E)', 'ko_KR').format(event.startDateTime)}$repeatSuffix',
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  color: colors.onSurfaceVariant,
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
          },
        );
      },
      loading: () => Center(key: key, child: const CircularProgressIndicator()),
      error: (_, _) => AppEmptyState(
        key: key,
        icon: Icons.cloud_off_outlined,
        title: '일정을 불러오지 못했습니다',
        message: '잠시 후 다시 시도해 주세요.',
      ),
    );
  }
}
