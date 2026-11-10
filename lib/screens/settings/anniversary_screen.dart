import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../models/anniversary_model.dart';
import '../../models/couple_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/calendar_provider.dart';
import '../../utils/dday_utils.dart';
import '../../utils/lunar_utils.dart';
import '../../widgets/app_surface.dart';

class AnniversaryScreen extends ConsumerWidget {
  const AnniversaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coupleAsync = ref.watch(coupleStreamProvider);
    final myUid = ref.watch(authStateProvider).valueOrNull?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('기념일 관리')),
      body: coupleAsync.when(
        data: (couple) {
          if (couple == null) {
            return const AppEmptyState(
              icon: Icons.favorite_border,
              title: '파트너 연결 후 사용할 수 있습니다',
              message: '둘만의 소중한 날을 함께 관리해 보세요.',
            );
          }
          final list = sortedForDisplay(couple.anniversaries, DateTime.now());
          if (list.isEmpty) {
            return AppEmptyState(
              icon: Icons.cake_outlined,
              title: '첫 기념일을 추가해 보세요',
              message: '함께한 날은 D+로, 매년 돌아오는 날은 기념일로 표시해요.',
              action: FilledButton.tonalIcon(
                onPressed: () => _showForm(context, ref, couple, myUid),
                icon: const Icon(Icons.add),
                label: const Text('기념일 추가'),
              ),
            );
          }
          return AppPageBody(
            child: ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 9),
              itemBuilder: (context, i) {
                final a = list[i];
                final colors = Theme.of(context).colorScheme;
                final owner = _ownerLabel(a, myUid);
                // 음력은 이번에 돌아오는 양력 날짜를 같이 보여 준다
                final when = a.isLunar
                    ? '음력 ${a.lunarMonth}월 ${a.lunarDay}일 '
                          '(양력 ${DateFormat('M월 d일').format(nextAnnualOccurrence(a, DateUtils.dateOnly(DateTime.now())))})'
                    : DateFormat('yyyy.MM.dd').format(a.date);
                return Card(
                  child: ListTile(
                    leading: AppIconBadge(
                      icon: a.type == AnniversaryType.countUp
                          ? Icons.favorite
                          : Icons.cake,
                      emphasized: true,
                    ),
                    title: Text(
                      a.title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      [
                        ?owner,
                        when,
                        a.type == AnniversaryType.countUp ? '카운트업' : '매년 반복',
                      ].join(' · '),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: colors.primaryContainer,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            dDayLabel(a, DateTime.now()),
                            style: TextStyle(
                              color: colors.onPrimaryContainer,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: '삭제',
                          icon: Icon(
                            Icons.delete_outline,
                            color: colors.onSurfaceVariant,
                          ),
                          onPressed: () => _confirmDelete(
                            context,
                            ref,
                            couple.coupleId,
                            couple.anniversaries,
                            a,
                          ),
                        ),
                      ],
                    ),
                    onTap: () =>
                        _showForm(context, ref, couple, myUid, existing: a),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => const Center(child: Text('불러오지 못했습니다')),
      ),
      floatingActionButton: coupleAsync.valueOrNull == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () =>
                  _showForm(context, ref, coupleAsync.value!, myUid),
              icon: const Icon(Icons.add),
              label: const Text('기념일 추가'),
            ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String coupleId,
    List<AnniversaryModel> current,
    AnniversaryModel target,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('기념일 삭제'),
        content: Text("'${target.title}'을(를) 삭제할까요?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final updated = current.where((a) => a.id != target.id).toList();
    await ref
        .read(firestoreServiceProvider)
        .updateAnniversaries(coupleId, updated);
  }

  Future<void> _showForm(
    BuildContext context,
    WidgetRef ref,
    CoupleModel couple,
    String? myUid, {
    AnniversaryModel? existing,
  }) async {
    final partnerUid = couple.ownerUid == myUid
        ? couple.partnerUid
        : couple.ownerUid;
    final result = await showDialog<AnniversaryModel>(
      context: context,
      builder: (ctx) => _AnniversaryFormDialog(
        existing: existing,
        myUid: myUid,
        partnerUid: partnerUid,
      ),
    );
    if (result == null) return;
    final updated = [
      ...couple.anniversaries.where((a) => a.id != result.id),
      result,
    ];
    await ref
        .read(firestoreServiceProvider)
        .updateAnniversaries(couple.coupleId, updated);
  }
}

/// 기념일 주인을 보는 사람 기준으로 — 둘의 기념일이면 null.
String? _ownerLabel(AnniversaryModel a, String? myUid) {
  final owner = a.ownerUid;
  if (owner == null) return null;
  return owner == myUid ? '나' : '파트너';
}

class _AnniversaryFormDialog extends StatefulWidget {
  final AnniversaryModel? existing;
  final String? myUid;
  final String partnerUid;
  const _AnniversaryFormDialog({
    this.existing,
    required this.myUid,
    required this.partnerUid,
  });

  @override
  State<_AnniversaryFormDialog> createState() => _AnniversaryFormDialogState();
}

class _AnniversaryFormDialogState extends State<_AnniversaryFormDialog> {
  late final TextEditingController _titleController;
  late DateTime _date;
  late AnniversaryType _type;
  late bool _isLunar;
  late int _lunarMonth;
  late int _lunarDay;

  /// 누구의 기념일인지. '' 이면 둘의 기념일 (SegmentedButton 값이라 null 대신)
  late String _owner;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.existing?.title ?? '',
    );
    _date = widget.existing?.date ?? DateUtils.dateOnly(DateTime.now());
    _type = widget.existing?.type ?? AnniversaryType.countUp;
    _isLunar = widget.existing?.isLunar ?? false;
    _lunarMonth = widget.existing?.lunarMonth ?? 1;
    _lunarDay = widget.existing?.lunarDay ?? 1;
    _owner = widget.existing?.ownerUid ?? '';
  }

  /// 음력 월·일 고르기. 연도는 매년 반복이라 필요 없다.
  Future<void> _pickLunar() async {
    var month = _lunarMonth;
    var day = _lunarDay;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('음력 날짜'),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DropdownButton<int>(
                value: month,
                items: [
                  for (var m = 1; m <= 12; m++)
                    DropdownMenuItem(value: m, child: Text('$m월')),
                ],
                onChanged: (v) => setLocal(() => month = v ?? month),
              ),
              const SizedBox(width: 16),
              DropdownButton<int>(
                value: day,
                items: [
                  for (var d = 1; d <= 30; d++)
                    DropdownMenuItem(value: d, child: Text('$d일')),
                ],
                onChanged: (v) => setLocal(() => day = v ?? day),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('확인'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      setState(() {
        _lunarMonth = month;
        _lunarDay = day;
      });
    }
  }

  /// 고른 음력 날짜가 이번에 떨어지는 양력 날짜
  Widget? _lunarSolarText() {
    final solar = nextLunarOccurrence(
      _lunarMonth,
      _lunarDay,
      DateUtils.dateOnly(DateTime.now()),
    );
    if (solar == null) return null;
    return Text('양력 ${DateFormat('yyyy.M.d').format(solar)}');
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? '기념일 추가' : '기념일 수정'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: '제목'),
            autofocus: true,
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: [
              const ButtonSegment(value: '', label: Text('우리')),
              if (widget.myUid != null)
                ButtonSegment(value: widget.myUid!, label: const Text('나')),
              if (widget.partnerUid.isNotEmpty)
                ButtonSegment(
                  value: widget.partnerUid,
                  label: const Text('파트너'),
                ),
            ],
            selected: {_owner},
            onSelectionChanged: (s) => setState(() => _owner = s.first),
          ),
          const SizedBox(height: 4),
          if (_type == AnniversaryType.annual && _isLunar)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('날짜'),
              subtitle: _lunarSolarText(),
              trailing: Text('음력 $_lunarMonth월 $_lunarDay일'),
              onTap: _pickLunar,
            )
          else
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('날짜'),
              trailing: Text(DateFormat('yyyy.MM.dd').format(_date)),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(1990),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
          const SizedBox(height: 4),
          SegmentedButton<AnniversaryType>(
            segments: const [
              ButtonSegment(
                value: AnniversaryType.countUp,
                label: Text('D+ 카운트업'),
              ),
              ButtonSegment(
                value: AnniversaryType.annual,
                label: Text('매년 반복'),
              ),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          if (_type == AnniversaryType.annual)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('음력'),
              subtitle: const Text('음력 생일처럼 매년 음력 날짜로 돌아와요'),
              value: _isLunar,
              onChanged: (v) => setState(() => _isLunar = v),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () {
            final title = _titleController.text.trim();
            if (title.isEmpty) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('제목을 입력하세요')));
              return;
            }
            final lunar = _type == AnniversaryType.annual && _isLunar;
            final today = DateUtils.dateOnly(DateTime.now());
            Navigator.pop(
              context,
              AnniversaryModel(
                id: widget.existing?.id ?? const Uuid().v4(),
                title: title,
                date: lunar
                    ? (nextLunarOccurrence(_lunarMonth, _lunarDay, today) ??
                          today)
                    : DateUtils.dateOnly(_date),
                type: _type,
                isLunar: lunar,
                lunarMonth: lunar ? _lunarMonth : null,
                lunarDay: lunar ? _lunarDay : null,
                ownerUid: _owner.isEmpty ? null : _owner,
              ),
            );
          },
          child: const Text('저장'),
        ),
      ],
    );
  }
}
