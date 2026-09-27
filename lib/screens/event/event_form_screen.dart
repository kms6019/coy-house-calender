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
import '../../utils/conflict_utils.dart';
import '../../widgets/app_surface.dart';

/// 반복 일정의 한 회차만 고칠 때 넘기는 값.
class EventOccurrenceEditArgs {
  final EventModel master;
  final EventModel occurrence; // 그 회차의 복사본 (시작 시각이 그 날짜)
  const EventOccurrenceEditArgs({
    required this.master,
    required this.occurrence,
  });
}

class EventFormScreen extends ConsumerStatefulWidget {
  final EventModel? event;
  final DateTime? initialDate;
  final String? initialTitle;

  /// 값이 있으면 "이 일정만 수정": [event] 는 그 회차 복사본이고, 저장하면
  /// 반복에서 그 날을 빼고 단일 일정으로 새로 만든다.
  final EventModel? seriesMaster;
  const EventFormScreen({
    super.key,
    this.event,
    this.initialDate,
    this.initialTitle,
    this.seriesMaster,
  });

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
  bool _hasAlarm = true; // 새 일정은 알림 켜짐이 기본 (기존 일정은 저장된 값을 따름)
  int _alarmMinutes = 30;
  RepeatRule _repeat = RepeatRule.none;
  DateTime? _repeatUntil;
  bool _isShared = false;
  bool _propose = false;
  bool _loading = false;
  int? _color; // null = 내 커플 색 (기본)
  String? _icon;

  static const _alarmOptions = [0, 15, 30, 60, 1440];
  static const _alarmLabels = ['시작 시', '15분 전', '30분 전', '1시간 전', '하루 전'];
  static const _repeatLabels = {
    RepeatRule.none: '반복 없음',
    RepeatRule.daily: '매일',
    RepeatRule.weekly: '매주',
    RepeatRule.biweekly: '격주',
    RepeatRule.monthly: '매월',
    RepeatRule.yearly: '매년',
  };

  @override
  void initState() {
    super.initState();
    final base =
        widget.event?.startDateTime ?? widget.initialDate ?? DateTime.now();
    _startDate = DateUtils.dateOnly(base);
    _startTime = widget.event != null
        ? TimeOfDay.fromDateTime(widget.event!.startDateTime)
        : TimeOfDay.now();
    _isShared = widget.event?.isShared ?? false;

    if (widget.event != null) {
      _titleCtrl.text = widget.event!.title;
      _descCtrl.text = widget.event!.description ?? '';
      _isAllDay = widget.event!.isAllDay;
      _hasAlarm = widget.event!.hasAlarm;
      _alarmMinutes = widget.event!.alarmMinutesBefore;
      // 한 회차만 고칠 때는 반복 없는 단일 일정이 된다
      _repeat = widget.seriesMaster != null
          ? RepeatRule.none
          : widget.event!.repeat;
      _repeatUntil = widget.seriesMaster != null
          ? null
          : widget.event!.repeatUntil;
      _color = widget.event!.color;
      _icon = widget.event!.icon;
      if (widget.event!.endDateTime != null) {
        _endDate = DateUtils.dateOnly(widget.event!.endDateTime!);
        _endTime = TimeOfDay.fromDateTime(widget.event!.endDateTime!);
      }
    } else if (widget.initialTitle != null) {
      _titleCtrl.text = widget.initialTitle!;
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
      : DateTime(
          _startDate.year,
          _startDate.month,
          _startDate.day,
          _startTime.hour,
          _startTime.minute,
        );

  DateTime? get _endDateTime {
    if (_endDate == null) return null;
    if (_isAllDay) return _endDate;
    final et = _endTime;
    if (et == null) return null;
    return DateTime(
      _endDate!.year,
      _endDate!.month,
      _endDate!.day,
      et.hour,
      et.minute,
    );
  }

  bool get _endBeforeStart {
    final end = _endDateTime;
    if (end == null) return false;
    return !_isAllDay && end.isBefore(_startDateTime);
  }

  String _conflictLabel(EventModel event) {
    final format = DateFormat('HH:mm');
    final end = event.endDateTime;
    final time = end != null
        ? '${format.format(event.startDateTime)}–${format.format(end)}'
        : format.format(event.startDateTime);
    return '${event.title} · $time';
  }

  /// 겹치는 일정이 있으면 확인 다이얼로그를 띄운다. 저장을 계속할지 여부를 반환.
  Future<bool> _confirmConflicts() async {
    final events =
        ref.read(eventsStreamProvider).valueOrNull ?? const <EventModel>[];
    final candidate = EventModel(
      id: widget.event?.id ?? '',
      coupleId: '',
      createdByUid: '',
      title: '',
      startDateTime: _startDateTime,
      endDateTime: _endDateTime,
      isAllDay: _isAllDay,
      color: 0,
      hasAlarm: false,
      alarmMinutesBefore: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final conflicts = findConflicts(events, candidate);
    if (conflicts.isEmpty) return true;
    if (!mounted) return false;

    final lines = conflicts.take(3).map(_conflictLabel).join('\n');
    final extra = conflicts.length > 3 ? '\n외 ${conflicts.length - 3}건' : '';

    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('일정이 겹칩니다'),
        content: Text('$lines$extra'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('그대로 저장'),
          ),
        ],
      ),
    );
    return proceed ?? false;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_endBeforeStart) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('종료 시간이 시작 시간보다 앞설 수 없습니다.')),
      );
      return;
    }

    if (!await _confirmConflicts()) return;
    if (!mounted) return;

    setState(() => _loading = true);

    final userModel = ref.read(currentUserModelProvider).valueOrNull;
    final authUid = ref.read(authStateProvider).valueOrNull?.uid;
    if (userModel == null || authUid == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('사용자 정보를 불러오지 못했습니다.')));
        setState(() => _loading = false);
      }
      return;
    }

    final couple = ref.read(coupleStreamProvider).valueOrNull;
    final coupleId = couple?.coupleId ?? userModel.coupleId;

    final color = couple != null
        ? (couple.ownerUid == authUid ? couple.ownerColor : couple.partnerColor)
        : 0xFF42A5F5;

    final effectiveColor = _color ?? color;

    try {
      final fs = ref.read(firestoreServiceProvider);
      final master = widget.seriesMaster;
      EventModel saved;
      EventModel? updatedMaster;

      if (widget.event == null || master != null) {
        final draft = EventModel(
          id: '',
          coupleId: coupleId,
          createdByUid: authUid,
          title: _titleCtrl.text.trim(),
          description: _descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim(),
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
          isShared: _isShared,
          status: master != null
              ? master.status
              : (_propose ? 'proposed' : 'confirmed'),
        );
        // 새 단일 일정을 먼저 만든 뒤 반복에서 그 날을 뺀다 — 중간에 실패해도
        // 일정이 사라지지 않고 잠시 겹칠 뿐이다.
        saved = await fs.addEvent(draft);
        if (master != null) {
          final day = DateUtils.dateOnly(widget.event!.startDateTime);
          updatedMaster = master.copyWithRepeat(
            repeat: master.repeat,
            repeatUntil: master.repeatUntil,
            excludedDates: {...master.excludedDates, day}.toList(),
          );
          await fs.updateEvent(updatedMaster, editorUid: authUid);
        }
      } else {
        saved = widget.event!.copyWith(
          title: _titleCtrl.text.trim(),
          description: _descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim(),
          startDateTime: _startDateTime,
          endDateTime: _endDateTime,
          isAllDay: _isAllDay,
          hasAlarm: _hasAlarm,
          alarmMinutesBefore: _alarmMinutes,
          updatedAt: DateTime.now(),
          isShared: _isShared,
        );
        saved = saved.copyWithRepeat(
          repeat: _repeat,
          repeatUntil: _repeat == RepeatRule.none ? null : _repeatUntil,
          excludedDates: _repeat == RepeatRule.none
              ? const []
              : widget.event!.excludedDates,
        );
        saved = saved.copyWith(color: effectiveColor).copyWithIcon(_icon);
        await fs.updateEvent(saved, editorUid: authUid);
      }

      final calendarSync = SamsungCalendarSyncService();
      if (widget.event == null || master != null) {
        if (!saved.isProposed) {
          await calendarSync.syncEventCreate(saved);
        }
      } else {
        await calendarSync.syncEventUpdate(saved);
      }
      if (updatedMaster != null) {
        await calendarSync.syncEventUpdate(updatedMaster);
      }

      String? warningMessage;
      final ns = NotificationService();
      try {
        await ns.cancelAlarm(saved.id);
        if (_hasAlarm) await ns.scheduleAlarm(saved);
        // 반복의 다음 알림이 방금 뺀 회차였을 수 있다
        if (updatedMaster != null) {
          await ns.cancelAlarm(updatedMaster.id);
          if (updatedMaster.hasAlarm) await ns.scheduleAlarm(updatedMaster);
        }
      } catch (_) {
        warningMessage = '일정은 저장됐지만 알림 설정은 완료되지 않았습니다.';
      }

      if (!mounted) return;
      context.go('/calendar');
      if (warningMessage != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(warningMessage)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('저장에 실패했습니다.')));
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
                      ? Icon(
                          Icons.check,
                          color:
                              ThemeData.estimateBrightnessForColor(Color(c)) ==
                                  Brightness.dark
                              ? Theme.of(ctx).colorScheme.surface
                              : Theme.of(ctx).colorScheme.onSurface,
                        )
                      : null,
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
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
                          color: Theme.of(ctx).colorScheme.primaryContainer,
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
            child: const Text('아이콘 제거'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isEdit = widget.event != null;
    final dateFmt = DateFormat('yyyy년 M월 d일 (E)', 'ko_KR');
    final dateFmtShort = DateFormat('M월 d일 (E)', 'ko_KR');

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.seriesMaster != null
              ? '이 일정만 수정'
              : (isEdit ? '일정 수정' : '일정 추가'),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.tonal(
              onPressed: _loading ? null : _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size(72, 42),
                padding: const EdgeInsets.symmetric(horizontal: 18),
              ),
              child: _loading
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.primary,
                      ),
                    )
                  : const Text('저장'),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: AppPageBody(
          child: ListView(
            children: [
              Text(
                isEdit ? '일정을 다듬어 볼까요?' : '어떤 하루를 함께할까요?',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 5),
              Text(
                '날짜부터 분위기까지 차근차근 정해 보세요.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _titleCtrl,
                autofocus: !isEdit,
                decoration: const InputDecoration(
                  hintText: '일정 제목',
                  prefixIcon: Icon(Icons.edit_calendar_outlined),
                ),
                style: theme.textTheme.titleLarge,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '제목을 입력하세요' : null,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 22),
              _EventFormSection(
                title: '날짜와 시간',
                subtitle: '시작과 종료 시간을 정해 주세요.',
                icon: Icons.calendar_month_outlined,
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('종일'),
                      secondary: const Icon(Icons.wb_sunny_outlined),
                      value: _isAllDay,
                      onChanged: (v) => setState(() {
                        _isAllDay = v;
                        if (v) _endTime = null;
                      }),
                    ),
                    const Divider(indent: 16, endIndent: 16),
                    ListTile(
                      leading: const AppIconBadge(
                        icon: Icons.calendar_today_outlined,
                      ),
                      title: const Text('시작 날짜'),
                      subtitle: Text(dateFmt.format(_startDate)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _pickDate(isStart: true),
                    ),
                    if (!_isAllDay)
                      ListTile(
                        leading: const AppIconBadge(
                          icon: Icons.access_time_outlined,
                        ),
                        title: const Text('시작 시간'),
                        subtitle: Text(_startTime.format(context)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _pickTime(isStart: true),
                      ),
                    const Divider(indent: 16, endIndent: 16),
                    if (_endDate != null) ...[
                      ListTile(
                        leading: const AppIconBadge(icon: Icons.event_outlined),
                        title: const Text('종료 날짜'),
                        subtitle: Text(dateFmtShort.format(_endDate!)),
                        trailing: IconButton(
                          tooltip: '종료 날짜 제거',
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => setState(() {
                            _endDate = null;
                            _endTime = null;
                          }),
                        ),
                        onTap: () => _pickDate(isStart: false),
                      ),
                      if (!_isAllDay)
                        ListTile(
                          leading: const AppIconBadge(
                            icon: Icons.schedule_outlined,
                          ),
                          title: const Text('종료 시간'),
                          subtitle: Text(
                            _endTime != null
                                ? _endTime!.format(context)
                                : '종료 시간 선택',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _pickTime(isStart: false),
                        ),
                      if (_endBeforeStart)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(70, 0, 16, 12),
                          child: Text(
                            '종료 시간이 시작보다 앞섭니다',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.error,
                            ),
                          ),
                        ),
                    ] else
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                          child: TextButton.icon(
                            onPressed: () => _pickDate(isStart: false),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('종료 날짜 추가'),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _EventFormSection(
                title: '알림과 반복',
                subtitle: '잊지 않도록 미리 알려 드릴게요.',
                icon: Icons.notifications_active_outlined,
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('알림'),
                      subtitle: Text(
                        _hasAlarm
                            ? _alarmLabels[_alarmOptions.indexOf(_alarmMinutes)]
                            : '사용 안 함',
                      ),
                      secondary: const Icon(Icons.notifications_outlined),
                      value: _hasAlarm,
                      onChanged: (v) => setState(() => _hasAlarm = v),
                    ),
                    if (_hasAlarm)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(70, 0, 18, 12),
                        child: DropdownButtonFormField<int>(
                          initialValue: _alarmMinutes,
                          decoration: const InputDecoration(labelText: '알림 시점'),
                          items: List.generate(
                            _alarmOptions.length,
                            (i) => DropdownMenuItem(
                              value: _alarmOptions[i],
                              child: Text(_alarmLabels[i]),
                            ),
                          ),
                          onChanged: (v) =>
                              setState(() => _alarmMinutes = v ?? 30),
                        ),
                      ),
                    if (widget.seriesMaster == null) ...[
                      const Divider(indent: 16, endIndent: 16),
                      ListTile(
                        leading: const Icon(Icons.repeat),
                        title: const Text('반복'),
                        trailing: DropdownButton<RepeatRule>(
                          value: _repeat,
                          underline: const SizedBox.shrink(),
                          items: RepeatRule.values
                              .map(
                                (r) => DropdownMenuItem(
                                  value: r,
                                  child: Text(_repeatLabels[r]!),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() {
                            _repeat = v ?? RepeatRule.none;
                            if (_repeat == RepeatRule.none) _repeatUntil = null;
                          }),
                        ),
                      ),
                      if (_repeat != RepeatRule.none)
                        ListTile(
                          contentPadding: const EdgeInsets.only(
                            left: 58,
                            right: 12,
                          ),
                          title: const Text('반복 종료'),
                          subtitle: Text(
                            _repeatUntil != null
                                ? dateFmtShort.format(_repeatUntil!)
                                : '계속 반복',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_repeatUntil != null)
                                IconButton(
                                  tooltip: '반복 종료일 제거',
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () =>
                                      setState(() => _repeatUntil = null),
                                ),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _repeatUntil ?? _startDate,
                              firstDate: _startDate,
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) {
                              setState(() => _repeatUntil = picked);
                            }
                          },
                        ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _EventFormSection(
                title: '함께하기',
                subtitle: '둘이 함께 보거나 상대에게 제안할 수 있어요.',
                icon: Icons.favorite_outline,
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('함께하는 일정'),
                      subtitle: const Text('두 사람의 일정으로 표시'),
                      secondary: const Icon(Icons.favorite_outline),
                      value: _isShared,
                      onChanged: (v) => setState(() => _isShared = v),
                    ),
                    if (widget.event == null) ...[
                      const Divider(indent: 16, endIndent: 16),
                      SwitchListTile(
                        title: const Text('상대에게 제안'),
                        subtitle: const Text('상대가 수락하면 일정 확정'),
                        secondary: const Icon(Icons.send_outlined),
                        value: _propose,
                        onChanged: (v) => setState(() => _propose = v),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _EventFormSection(
                title: '꾸미기',
                subtitle: '달력에서 한눈에 알아볼 수 있게 꾸며 보세요.',
                icon: Icons.auto_awesome_outlined,
                child: Column(
                  children: [
                    Builder(
                      builder: (context) {
                        final couple = ref
                            .watch(coupleStreamProvider)
                            .valueOrNull;
                        final authUid = ref
                            .watch(authStateProvider)
                            .valueOrNull
                            ?.uid;
                        final defaultColor = couple != null
                            ? (couple.ownerUid == authUid
                                  ? couple.ownerColor
                                  : couple.partnerColor)
                            : 0xFF42A5F5;
                        final shown = _color ?? defaultColor;
                        return ListTile(
                          leading: const Icon(Icons.palette_outlined),
                          title: const Text('색상'),
                          subtitle: const Text('일정 막대와 표시 점 색상'),
                          trailing: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: Color(shown),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: colors.outlineVariant,
                                width: 2,
                              ),
                            ),
                          ),
                          onTap: () => _pickColor(shown),
                        );
                      },
                    ),
                    const Divider(indent: 16, endIndent: 16),
                    ListTile(
                      leading: const Icon(Icons.emoji_emotions_outlined),
                      title: const Text('아이콘'),
                      subtitle: const Text('제목 앞에 표시'),
                      trailing: Text(
                        _icon ?? '없음',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: _icon != null
                              ? colors.onSurface
                              : colors.onSurfaceVariant,
                        ),
                      ),
                      onTap: _pickIcon,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _EventFormSection(
                title: '메모',
                subtitle: '필요한 내용을 자유롭게 적어 두세요.',
                icon: Icons.notes_outlined,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: TextFormField(
                    controller: _descCtrl,
                    decoration: const InputDecoration(
                      hintText: '장소, 준비물, 기억하고 싶은 내용을 적어 보세요.',
                    ),
                    maxLines: null,
                    minLines: 4,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventFormSection extends StatelessWidget {
  const _EventFormSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(title: title, subtitle: subtitle, icon: icon),
        AppSectionCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: child,
        ),
      ],
    );
  }
}
