import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers/auth_provider.dart';
import '../../providers/calendar_provider.dart';
import '../../utils/report_utils.dart';
import '../../widgets/app_surface.dart';

class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  void _moveMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
    });
  }

  @override
  Widget build(BuildContext context) {
    final couple = ref.watch(coupleStreamProvider).valueOrNull;
    final events = ref.watch(eventsStreamProvider).valueOrNull ?? [];
    final wishes = ref.watch(wishesStreamProvider).valueOrNull ?? [];
    final myUid = ref.watch(authStateProvider).valueOrNull?.uid ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('월간 리포트')),
      body: couple == null
          ? const AppEmptyState(
              icon: Icons.favorite_border,
              title: '파트너 연결 후 사용할 수 있습니다',
              message: '둘의 일정을 모아 월간 이야기를 만들어 드려요.',
            )
          : Builder(
              builder: (context) {
                final report = buildMonthlyReport(
                  events: events,
                  wishes: wishes,
                  month: _month,
                  myUid: myUid,
                );

                return AppPageBody(
                  child: ListView(
                    children: [
                      _MonthSelector(
                        month: _month,
                        onPrevious: () => _moveMonth(-1),
                        onNext: () => _moveMonth(1),
                      ),
                      const SizedBox(height: 18),
                      _EventReportCard(
                        totalEvents: report.totalEvents,
                        myEvents: report.myEvents,
                        partnerEvents: report.partnerEvents,
                        allDayEvents: report.allDayEvents,
                      ),
                      if (report.topIcon != null) ...[
                        const SizedBox(height: 14),
                        _TopIconReportCard(topIcon: report.topIcon!),
                      ],
                      const SizedBox(height: 14),
                      _WishReportCard(
                        done: report.wishesDone,
                        total: report.wishesTotal,
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _MonthSelector extends StatelessWidget {
  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _MonthSelector({
    required this.month,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: '이전 달',
            icon: const Icon(Icons.chevron_left),
            color: colors.onPrimaryContainer,
            onPressed: onPrevious,
          ),
          Expanded(
            child: Text(
              DateFormat('yyyy년 M월').format(month),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                color: colors.onPrimaryContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            tooltip: '다음 달',
            icon: const Icon(Icons.chevron_right),
            color: colors.onPrimaryContainer,
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

class _EventReportCard extends StatelessWidget {
  final int totalEvents;
  final int myEvents;
  final int partnerEvents;
  final int allDayEvents;

  const _EventReportCard({
    required this.totalEvents,
    required this.myEvents,
    required this.partnerEvents,
    required this.allDayEvents,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colors.secondaryContainer,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.auto_awesome, color: colors.onSecondaryContainer),
              const SizedBox(height: 12),
              Text(
                '이번 달 함께 만든 일정',
                style: textTheme.bodyLarge?.copyWith(
                  color: colors.onSecondaryContainer,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$totalEvents건',
                style: textTheme.headlineLarge?.copyWith(
                  color: colors.onSecondaryContainer,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ReportStat(
                icon: Icons.person_outline,
                label: '내 일정',
                value: '$myEvents',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ReportStat(
                icon: Icons.favorite_outline,
                label: '상대 일정',
                value: '$partnerEvents',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ReportStat(
                icon: Icons.wb_sunny_outlined,
                label: '종일 일정',
                value: '$allDayEvents',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ReportStat extends StatelessWidget {
  const _ReportStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        child: Column(
          children: [
            Icon(icon, color: colors.primary),
            const SizedBox(height: 8),
            Text(value, style: theme.textTheme.titleLarge),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopIconReportCard extends StatelessWidget {
  final String topIcon;

  const _TopIconReportCard({required this.topIcon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.tertiaryContainer,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(topIcon, style: const TextStyle(fontSize: 38)),
            ),
            const SizedBox(height: 8),
            Text(
              '이번 달 최애 아이콘',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WishReportCard extends StatelessWidget {
  final int done;
  final int total;

  const _WishReportCard({required this.done, required this.total});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final progress = total == 0 ? 0.0 : done / total;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('위시리스트 완료 $done / $total', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              borderRadius: BorderRadius.circular(99),
            ),
            const SizedBox(height: 8),
            Text(
              total == 0
                  ? '첫 번째 위시를 추가해 보세요.'
                  : '${(progress * 100).round()}% 완료',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
