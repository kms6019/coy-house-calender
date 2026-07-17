import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers/auth_provider.dart';
import '../../providers/calendar_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/report_utils.dart';

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
          ? const Center(child: Text('파트너 연결 후 사용할 수 있습니다'))
          : Builder(
              builder: (context) {
                final report = buildMonthlyReport(
                  events: events,
                  wishes: wishes,
                  month: _month,
                  myUid: myUid,
                );

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _MonthSelector(
                      month: _month,
                      onPrevious: () => _moveMonth(-1),
                      onNext: () => _moveMonth(1),
                    ),
                    const SizedBox(height: 12),
                    _EventReportCard(
                      totalEvents: report.totalEvents,
                      myEvents: report.myEvents,
                      partnerEvents: report.partnerEvents,
                      allDayEvents: report.allDayEvents,
                    ),
                    if (report.topIcon != null) ...[
                      const SizedBox(height: 12),
                      _TopIconReportCard(topIcon: report.topIcon!),
                    ],
                    const SizedBox(height: 12),
                    _WishReportCard(
                      done: report.wishesDone,
                      total: report.wishesTotal,
                    ),
                  ],
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: '이전 달',
          icon: const Icon(Icons.chevron_left),
          onPressed: onPrevious,
        ),
        Expanded(
          child: Text(
            DateFormat('yyyy년 M월').format(month),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        IconButton(
          tooltip: '다음 달',
          icon: const Icon(Icons.chevron_right),
          onPressed: onNext,
        ),
      ],
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
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '이번 달 일정 $totalEvents건',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '나 $myEvents · 상대 $partnerEvents · 종일 $allDayEvents',
              style: textTheme.bodyMedium?.copyWith(color: Colors.grey),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(topIcon, style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 8),
            Text(
              '이번 달 최애 아이콘',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
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

  const _WishReportCard({
    required this.done,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : done / total;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '위시리스트 완료 $done / $total',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress,
              color: kPrimaryPurple,
            ),
          ],
        ),
      ),
    );
  }
}
