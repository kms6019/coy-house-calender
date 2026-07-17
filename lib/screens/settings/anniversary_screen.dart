import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../models/anniversary_model.dart';
import '../../providers/calendar_provider.dart';
import '../../utils/dday_utils.dart';

class AnniversaryScreen extends ConsumerWidget {
  const AnniversaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coupleAsync = ref.watch(coupleStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('기념일 관리')),
      body: coupleAsync.when(
        data: (couple) {
          if (couple == null) {
            return const Center(child: Text('파트너 연결 후 사용할 수 있습니다'));
          }
          final list = sortedForDisplay(couple.anniversaries, DateTime.now());
          if (list.isEmpty) {
            return Center(
              child: Text('기념일을 추가해보세요',
                  style: TextStyle(color: Colors.grey[400])),
            );
          }
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final a = list[i];
              return ListTile(
                leading: Icon(
                  a.type == AnniversaryType.countUp
                      ? Icons.favorite
                      : Icons.cake,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(a.title),
                subtitle: Text(
                  '${DateFormat('yyyy.MM.dd').format(a.date)} · ${a.type == AnniversaryType.countUp ? '카운트업' : '매년 반복'}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      dDayLabel(a, DateTime.now()),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.grey),
                      onPressed: () => _confirmDelete(context, ref, couple.coupleId,
                          couple.anniversaries, a),
                    ),
                  ],
                ),
                onTap: () => _showForm(context, ref, couple.coupleId,
                    couple.anniversaries, existing: a),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => const Center(child: Text('불러오지 못했습니다')),
      ),
      floatingActionButton: coupleAsync.valueOrNull == null
          ? null
          : FloatingActionButton(
              onPressed: () => _showForm(
                context,
                ref,
                coupleAsync.value!.coupleId,
                coupleAsync.value!.anniversaries,
              ),
              child: const Icon(Icons.add),
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
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('삭제')),
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
    String coupleId,
    List<AnniversaryModel> current, {
    AnniversaryModel? existing,
  }) async {
    final result = await showDialog<AnniversaryModel>(
      context: context,
      builder: (ctx) => _AnniversaryFormDialog(existing: existing),
    );
    if (result == null) return;
    final updated = [
      ...current.where((a) => a.id != result.id),
      result,
    ];
    await ref
        .read(firestoreServiceProvider)
        .updateAnniversaries(coupleId, updated);
  }
}

class _AnniversaryFormDialog extends StatefulWidget {
  final AnniversaryModel? existing;
  const _AnniversaryFormDialog({this.existing});

  @override
  State<_AnniversaryFormDialog> createState() => _AnniversaryFormDialogState();
}

class _AnniversaryFormDialogState extends State<_AnniversaryFormDialog> {
  late final TextEditingController _titleController;
  late DateTime _date;
  late AnniversaryType _type;

  @override
  void initState() {
    super.initState();
    _titleController =
        TextEditingController(text: widget.existing?.title ?? '');
    _date = widget.existing?.date ?? DateUtils.dateOnly(DateTime.now());
    _type = widget.existing?.type ?? AnniversaryType.countUp;
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
                  value: AnniversaryType.countUp, label: Text('D+ 카운트업')),
              ButtonSegment(
                  value: AnniversaryType.annual, label: Text('매년 반복')),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('취소')),
        FilledButton(
          onPressed: () {
            final title = _titleController.text.trim();
            if (title.isEmpty) return;
            Navigator.pop(
              context,
              AnniversaryModel(
                id: widget.existing?.id ?? const Uuid().v4(),
                title: title,
                date: DateUtils.dateOnly(_date),
                type: _type,
              ),
            );
          },
          child: const Text('저장'),
        ),
      ],
    );
  }
}
