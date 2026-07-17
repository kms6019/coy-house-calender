import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/event_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/calendar_provider.dart';
import '../../services/notification_service.dart';
import '../../services/samsung_calendar_sync_service.dart';
import '../../theme/couple_palette.dart';
import '../../theme/event_icons.dart';

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
  RepeatRule _repeat = RepeatRule.none;
  DateTime? _repeatUntil;
  bool _loading = false;
  int? _color; // null = 내 커플 색 (기본)
  String? _icon;

  static const _alarmOptions = [0, 15, 30, 60, 1440];
  static const _alarmLabels = ['시작 시', '15분 전', '30분 전', '1시간 전', '하루 전'];
  static const _repeatLabels = {
    RepeatRule.none: '반복 없음',
    RepeatRule.daily: '매일',
    RepeatRule.weekly: '매주',
    RepeatRule.monthly: '매월',
    RepeatRule.yearly: '매년',
  };

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
      _repeat = widget.event!.repeat;
      _repeatUntil = widget.event!.repeatUntil;
      _color = widget.event!.color;
      _icon = widget.event!.icon;
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
    final et = _endTime;
    if (et == null) return null;
    return DateTime(_endDate!.year, _endDate!.month, _endDate!.day,
        et.hour, et.minute);
  }

  bool get _endBeforeStart {
    final end = _endDateTime;
    if (end == null) return false;
    return !_isAllDay && end.isBefore(_startDateTime);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_endBeforeStart) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('종료 시간이 시작 시간보다 앞설 수 없습니다.')),
      );
      return;
    }

    setState(() => _loading = true);

    final userModel = ref.read(currentUserModelProvider).valueOrNull;
    final authUid = ref.read(authStateProvider).valueOrNull?.uid;
    if (userModel == null || authUid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('사용자 정보를 불러오지 못했습니다.')),
        );
        setState(() => _loading = false);
      }
      return;
    }

    final couple = ref.read(coupleStreamProvider).valueOrNull;
    final coupleId = couple?.coupleId ?? userModel.coupleId;

    final color = couple != null
        ? (couple.ownerUid == authUid
            ? couple.ownerColor
            : couple.partnerColor)
        : 0xFF42A5F5;

    final effectiveColor = _color ?? color;

    try {
      final fs = ref.read(firestoreServiceProvider);
      EventModel saved;

      if (widget.event == null) {
        final draft = EventModel(
          id: '',
          coupleId: coupleId,
          createdByUid: authUid,
          title: _titleCtrl.text.trim(),
          description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          startDateTime: _startDateTime,
          endDateTime: _endDateTime,
          isAllDay: _isAllDay,
          color: effectiveColor,
          hasAlarm: _hasAlarm,
          alarmMinutesBefore: _alarmMinutes,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          repeat: _repeat,
          repeatUntil: _repeat == RepeatRule.none ? null : _repeatUntil,
          icon: _icon,
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
        saved = saved.copyWithRepeat(
          repeat: _repeat,
          repeatUntil: _repeat == RepeatRule.none ? null : _repeatUntil,
          excludedDates:
              _repeat == RepeatRule.none ? const [] : widget.event!.excludedDates,
        );
        saved = saved.copyWith(color: effectiveColor).copyWithIcon(_icon);
        await fs.updateEvent(saved);
      }

      final calendarSync = SamsungCalendarSyncService();
      if (widget.event == null) {
        await calendarSync.syncEventCreate(saved);
      } else {
        await calendarSync.syncEventUpdate(saved);
      }

      String? warningMessage;
      final ns = NotificationService();
      try {
        await ns.cancelAlarm(saved.id);
        if (_hasAlarm) await ns.scheduleAlarm(saved);
      } catch (_) {
        warningMessage = '일정은 저장됐지만 알림 설정은 완료되지 않았습니다.';
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

  Future<void> _pickColor(int current) async {
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('색상 선택'),
        content: SizedBox(
          width: 280,
          child: GridView.count(
            shrinkWrap: true,
            crossAxisCount: 4,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: kCouplePalette.map((c) {
              return InkWell(
                onTap: () => Navigator.pop(ctx, c),
                customBorder: const CircleBorder(),
                child: Container(
                  decoration: BoxDecoration(
                    color: Color(c),
                    shape: BoxShape.circle,
                  ),
                  child: c == current
                      ? const Icon(Icons.check, color: Colors.white)
                      : null,
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
        ],
      ),
    );
    if (picked != null) setState(() => _color = picked);
  }

  Future<void> _pickIcon() async {
    // sentinel: '' = 없음 선택
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('아이콘 선택'),
        content: SizedBox(
          width: 300,
          child: GridView.count(
            shrinkWrap: true,
            crossAxisCount: 6,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: kEventIcons.map((emoji) {
              return InkWell(
                onTap: () => Navigator.pop(ctx, emoji),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  alignment: Alignment.center,
                  decoration: _icon == emoji
                      ? BoxDecoration(
                          color: Colors.deepPurple.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        )
                      : null,
                  child: Text(emoji, style: const TextStyle(fontSize: 24)),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, ''),
              child: const Text('아이콘 제거')),
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
        ],
      ),
    );
    if (picked == null) return;
    setState(() => _icon = picked.isEmpty ? null : picked);
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
      if (isStart) {
        _startDate = picked;
        // 종료일이 시작일보다 앞이면 초기화
        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = null;
          _endTime = null;
        }
      } else {
        _endDate = picked;
        // 처음 종료일을 고를 때 시간이 없으면 시작 시간 +1h 로 자동 설정
        if (_endTime == null && !_isAllDay) {
          final startMinutes = _startTime.hour * 60 + _startTime.minute + 60;
          _endTime = TimeOfDay(
            hour: (startMinutes ~/ 60) % 24,
            minute: startMinutes % 60,
          );
        }
      }
    });
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : (_endTime ?? _startTime),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startTime = picked;
      } else {
        _endTime = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.event != null;
    final dateFmt = DateFormat('yyyy년 M월 d일 (E)', 'ko_KR');
    final dateFmtShort = DateFormat('M월 d일 (E)', 'ko_KR');

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? '일정 수정' : '일정 추가'),
        actions: [
          TextButton(
            onPressed: _loading ? null : _save,
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: _loading
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('저장'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 제목
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                hintText: '제목',
                border: InputBorder.none,
              ),
              style: Theme.of(context).textTheme.titleLarge,
              validator: (v) => (v == null || v.trim().isEmpty) ? '제목을 입력하세요' : null,
              textInputAction: TextInputAction.next,
            ),
            const Divider(),

            // 종일 스위치
            SwitchListTile(
              title: const Text('종일'),
              value: _isAllDay,
              onChanged: (v) => setState(() {
                _isAllDay = v;
                if (v) { _endTime = null; }
              }),
              contentPadding: EdgeInsets.zero,
            ),
            const Divider(),

            // 시작 날짜
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined),
              title: Text(dateFmt.format(_startDate)),
              onTap: () => _pickDate(isStart: true),
            ),
            // 시작 시간
            if (!_isAllDay)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.access_time_outlined),
                title: Text(_startTime.format(context)),
                onTap: () => _pickTime(isStart: true),
              ),
            const Divider(),

            // 종료 날짜/시간
            if (_endDate != null) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: Text('종료: ${dateFmtShort.format(_endDate!)}'),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() { _endDate = null; _endTime = null; }),
                ),
                onTap: () => _pickDate(isStart: false),
              ),
              if (!_isAllDay)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.access_time_outlined),
                  title: Text(_endTime != null
                      ? _endTime!.format(context)
                      : '종료 시간 선택'),
                  subtitle: _endBeforeStart
                      ? const Text('종료 시간이 시작보다 앞섭니다',
                          style: TextStyle(color: Colors.red, fontSize: 12))
                      : null,
                  onTap: () => _pickTime(isStart: false),
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

            // 반복
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.repeat),
              title: const Text('반복'),
              trailing: DropdownButton<RepeatRule>(
                value: _repeat,
                underline: const SizedBox.shrink(),
                items: RepeatRule.values
                    .map((r) => DropdownMenuItem(
                          value: r,
                          child: Text(_repeatLabels[r]!),
                        ))
                    .toList(),
                onChanged: (v) => setState(() {
                  _repeat = v ?? RepeatRule.none;
                  if (_repeat == RepeatRule.none) _repeatUntil = null;
                }),
              ),
            ),
            if (_repeat != RepeatRule.none)
              ListTile(
                contentPadding: const EdgeInsets.only(left: 40),
                title: Text(_repeatUntil != null
                    ? '종료: ${dateFmtShort.format(_repeatUntil!)}'
                    : '반복 종료일 (선택 안 함 = 계속 반복)'),
                trailing: _repeatUntil != null
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setState(() => _repeatUntil = null),
                      )
                    : null,
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _repeatUntil ?? _startDate,
                    firstDate: _startDate, // 시작일 이전 방지
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) setState(() => _repeatUntil = picked);
                },
              ),
            const Divider(),

            // 색상
            Builder(builder: (context) {
              final couple = ref.watch(coupleStreamProvider).valueOrNull;
              final authUid = ref.watch(authStateProvider).valueOrNull?.uid;
              final defaultColor = couple != null
                  ? (couple.ownerUid == authUid
                      ? couple.ownerColor
                      : couple.partnerColor)
                  : 0xFF42A5F5;
              final shown = _color ?? defaultColor;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.palette_outlined),
                title: const Text('색상'),
                trailing: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Color(shown),
                    shape: BoxShape.circle,
                  ),
                ),
                onTap: () => _pickColor(shown),
              );
            }),
            // 아이콘
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.emoji_emotions_outlined),
              title: const Text('아이콘'),
              trailing: Text(_icon ?? '없음',
                  style: TextStyle(
                      fontSize: _icon != null ? 22 : 14,
                      color: _icon != null ? null : Colors.grey)),
              onTap: _pickIcon,
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
