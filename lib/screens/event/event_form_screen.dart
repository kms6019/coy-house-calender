import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/event_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/calendar_provider.dart';
import '../../services/notification_service.dart';

class EventFormScreen extends ConsumerStatefulWidget {
  final EventModel? event;
  final DateTime? initialDate;
  const EventFormScreen({super.key, this.event, this.initialDate});

  @override
  ConsumerState<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends ConsumerState<EventFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  late DateTime _startDate;
  late TimeOfDay _startTime;
  DateTime? _endDate;
  TimeOfDay? _endTime;
  bool _isAllDay = false;
  bool _hasAlarm = false;
  int _alarmMinutes = 30;
  bool _loading = false;

  static const _alarmOptions = [0, 15, 30, 60, 1440];
  static const _alarmLabels = ['시작 시', '15분 전', '30분 전', '1시간 전', '하루 전'];

  @override
  void initState() {
    super.initState();
    final base = widget.event?.startDateTime ?? widget.initialDate ?? DateTime.now();
    _startDate = DateUtils.dateOnly(base);
    _startTime = widget.event != null
        ? TimeOfDay.fromDateTime(widget.event!.startDateTime)
        : TimeOfDay.now();

    if (widget.event != null) {
      _titleCtrl.text = widget.event!.title;
      _descCtrl.text = widget.event!.description ?? '';
      _isAllDay = widget.event!.isAllDay;
      _hasAlarm = widget.event!.hasAlarm;
      _alarmMinutes = widget.event!.alarmMinutesBefore;
      if (widget.event!.endDateTime != null) {
        _endDate = DateUtils.dateOnly(widget.event!.endDateTime!);
        _endTime = TimeOfDay.fromDateTime(widget.event!.endDateTime!);
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  DateTime get _startDateTime => _isAllDay
      ? _startDate
      : DateTime(_startDate.year, _startDate.month, _startDate.day,
            _startTime.hour, _startTime.minute);

  DateTime? get _endDateTime {
    if (_endDate == null) return null;
    if (_isAllDay) return _endDate;
    if (_endTime == null) return null;
    return DateTime(_endDate!.year, _endDate!.month, _endDate!.day,
        _endTime!.hour, _endTime!.minute);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final userModel = ref.read(currentUserModelProvider).valueOrNull;
    if (userModel == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('?ъ슜???뺣낫瑜?遺덈윭?ㅼ? 紐삵뻽?듬땲??')),
        );
        setState(() => _loading = false);
      }
      return;
    }

    final couple = ref.read(coupleStreamProvider).valueOrNull;
    final coupleId = couple?.coupleId ?? userModel.coupleId;

    final color = couple != null
        ? (couple.ownerUid == userModel.uid
            ? couple.ownerColor
            : couple.partnerColor)
        : 0xFF42A5F5;

    try {
      final fs = ref.read(firestoreServiceProvider);
      EventModel saved;

      if (widget.event == null) {
        final draft = EventModel(
          id: '',
          coupleId: coupleId,
          createdByUid: userModel.uid,
          title: _titleCtrl.text.trim(),
          description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          startDateTime: _startDateTime,
          endDateTime: _endDateTime,
          isAllDay: _isAllDay,
          color: color,
          hasAlarm: _hasAlarm,
          alarmMinutesBefore: _alarmMinutes,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        saved = await fs.addEvent(draft);
      } else {
        saved = widget.event!.copyWith(
          title: _titleCtrl.text.trim(),
          description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          startDateTime: _startDateTime,
          endDateTime: _endDateTime,
          isAllDay: _isAllDay,
          hasAlarm: _hasAlarm,
          alarmMinutesBefore: _alarmMinutes,
          updatedAt: DateTime.now(),
        );
        await fs.updateEvent(saved);
      }

      String? warningMessage;
      final ns = NotificationService();
      try {
        await ns.cancelAlarm(saved.id);
        if (_hasAlarm) await ns.scheduleAlarm(saved);
      } catch (_) {
        warningMessage = '?쇱젙????λ릺?덉?留??뚮┝ ?ㅼ젙? ?꾨즺?섏? 紐삵뻽?듬땲??';
      }

      if (!mounted) return;
      context.go('/calendar');
      if (warningMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(warningMessage)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장에 실패했습니다.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : (_endDate ?? _startDate),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) { _startDate = picked; }
      else { _endDate = picked; }
    });
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : (_endTime ?? _startTime),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) { _startTime = picked; }
      else { _endTime = picked; }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.event != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? '일정 수정' : '일정 추가'),
        actions: [
          TextButton(
            onPressed: _loading ? null : _save,
            child: _loading
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('저장'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                hintText: '제목',
                border: InputBorder.none,
              ),
              style: Theme.of(context).textTheme.titleLarge,
              validator: (v) => (v == null || v.trim().isEmpty) ? '제목을 입력하세요' : null,
            ),
            const Divider(),
            SwitchListTile(
              title: const Text('종일'),
              value: _isAllDay,
              onChanged: (v) => setState(() => _isAllDay = v),
              contentPadding: EdgeInsets.zero,
            ),
            const Divider(),
            // 시작 날짜/시간
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined),
              title: Text(DateFormat('yyyy년 M월 d일 (E)', 'ko_KR').format(_startDate)),
              onTap: () => _pickDate(isStart: true),
            ),
            if (!_isAllDay)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.access_time_outlined),
                title: Text(_startTime.format(context)),
                onTap: () => _pickTime(isStart: true),
              ),
            const Divider(),
            // 종료 날짜/시간
            if (_endDate != null || _endTime != null) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: Text('종료: ${DateFormat('M월 d일').format(_endDate ?? _startDate)}'
                    '${!_isAllDay && _endTime != null ? ' ${_endTime!.format(context)}' : ''}'),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() { _endDate = null; _endTime = null; }),
                ),
                onTap: () => _pickDate(isStart: false),
              ),
              const Divider(),
            ] else ...[
              TextButton.icon(
                onPressed: () => _pickDate(isStart: false),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('종료 날짜 추가'),
              ),
              const Divider(),
            ],
            // 알림
            SwitchListTile(
              title: const Text('알림'),
              secondary: const Icon(Icons.notifications_outlined),
              value: _hasAlarm,
              onChanged: (v) => setState(() => _hasAlarm = v),
              contentPadding: EdgeInsets.zero,
            ),
            if (_hasAlarm)
              Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 8),
                child: DropdownButton<int>(
                  value: _alarmMinutes,
                  items: List.generate(_alarmOptions.length, (i) => DropdownMenuItem(
                    value: _alarmOptions[i],
                    child: Text(_alarmLabels[i]),
                  )),
                  onChanged: (v) => setState(() => _alarmMinutes = v ?? 30),
                ),
              ),
            const Divider(),
            // 메모
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                hintText: '메모 추가',
                border: InputBorder.none,
                prefixIcon: Icon(Icons.notes_outlined),
              ),
              maxLines: null,
              minLines: 3,
            ),
          ],
        ),
      ),
    );
  }
}
