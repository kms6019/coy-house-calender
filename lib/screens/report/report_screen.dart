import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../providers/calendar_provider.dart';
import '../../theme/design_tokens.dart';
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
                      const SizedBox(height: 22),
                      _EventReportCard(
                        totalEvents: report.totalEvents,
                        myEvents: report.myEvents,
                        partnerEvents: report.partnerEvents,
                        allDayEvents: report.allDayEvents,
                      ),
                      if (report.topIcon != null)
                        _TopIconReportCard(topIcon: report.topIcon!),
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

/// 월 이동. 큰 숫자는 아래 합계 하나에만 쓴다.
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
    final t = DesignTokens.of(context);
    return Row(
      children: [
        Text(
          '${month.year}년 ${month.month}월',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: t.ink,
          ),
        ),
        const Spacer(),
        IconButton(
          tooltip: '이전 달',
          icon: const Icon(Icons.chevron_left),
          color: t.ink70,
          onPressed: onPrevious,
        ),
        IconButton(
          tooltip: '다음 달',
          icon: const Icon(Icons.chevron_right),
          color: t.ink70,
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
    final t = DesignTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '이번 달 함께 만든 일정',
          style: TextStyle(fontSize: 13, color: t.ink45),
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '$totalEvents',
              style: TextStyle(
                fontSize: 80,
                height: 0.95,
                fontWeight: FontWeight.w200,
                letterSpacing: -3.5,
                color: t.ink,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '건',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: t.ink,
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: t.line)),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _ReportStat(label: '내 일정', value: myEvents)),
                Container(width: 1, color: t.hairline),
                Expanded(
                  child: _ReportStat(label: '상대 일정', value: partnerEvents),
                ),
                Container(width: 1, color: t.hairline),
                Expanded(
                  child: _ReportStat(label: '종일 일정', value: allDayEvents),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ReportStat extends StatelessWidget {
  const _ReportStat({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final t = DesignTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 16),
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 28,
              height: 1,
              fontWeight: FontWeight.w300,
              letterSpacing: -0.8,
              color: t.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            style: TextStyle(fontSize: 12, color: t.ink45),
          ),
        ],
      ),
    );
  }
}

/// 라벨 왼쪽, 값 오른쪽의 한 줄. 위쪽 가는 선으로 구분.
class _ReportLine extends StatelessWidget {
  final String label;
  final Widget trailing;
  final Widget? below;

  const _ReportLine({required this.label, required this.trailing, this.below});

  @override
  Widget build(BuildContext context) {
    final t = DesignTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: t.hairline)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.2,
                    color: t.ink,
                  ),
                ),
              ),
              trailing,
            ],
          ),
          if (below != null) ...[const SizedBox(height: 12), below!],
        ],
      ),
    );
  }
}

class _TopIconReportCard extends StatelessWidget {
  final String topIcon;

  const _TopIconReportCard({required this.topIcon});

  @override
  Widget build(BuildContext context) {
    return _ReportLine(
      label: '가장 많이 쓴 아이콘',
      trailing: Text(topIcon, style: const TextStyle(fontSize: 26)),
    );
  }
}

class _WishReportCard extends StatelessWidget {
  final int done;
  final int total;

  const _WishReportCard({required this.done, required this.total});

  @override
  Widget build(BuildContext context) {
    final t = DesignTokens.of(context);
    final progress = total == 0 ? 0.0 : done / total;

    return _ReportLine(
      label: '위시리스트 완료',
      trailing: Text(
        total == 0 ? '첫 위시를 추가해 보세요' : '$done / $total',
        style: TextStyle(
          fontSize: total == 0 ? 13 : 15,
          fontWeight: FontWeight.w600,
          color: total == 0 ? t.ink45 : t.ink,
        ),
      ),
      below: total == 0
          ? null
          : LinearProgressIndicator(
              value: progress,
              minHeight: 3,
              color: t.ink,
              backgroundColor: t.fill,
              borderRadius: BorderRadius.circular(99),
            ),
    );
  }
}
