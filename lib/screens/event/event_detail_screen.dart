import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../models/event_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/calendar_provider.dart';
import '../../services/notification_service.dart';
import '../../services/samsung_calendar_sync_service.dart';
import '../../theme/design_tokens.dart';
import '../../utils/event_utils.dart';
import '../../widgets/app_surface.dart';

class EventDetailArgs {
  final EventModel event; // occurrence 복사본 (표시용)
  final DateTime occurrenceDate; // 열어본 회차 날짜 (자정)
  const EventDetailArgs({required this.event, required this.occurrenceDate});
}

class EventDetailScreen extends ConsumerWidget {
  final EventModel event;
  final DateTime? occurrenceDate;
  const EventDetailScreen({
    super.key,
    required this.event,
    this.occurrenceDate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final currentUid = ref.watch(authStateProvider).valueOrNull?.uid;
    // 반복 이벤트의 event는 occurrence 복사본 — 수정/삭제는 마스터 기준
    final master =
        ref
            .watch(eventsStreamProvider)
            .valueOrNull
            ?.firstWhere((e) => e.id == event.id, orElse: () => event) ??
        event;
    final isOwner =
        event.createdByUid == currentUid || event.createdByUid.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('일정 상세'),
        actions: [
          if (isOwner) ...[
            IconButton(
              tooltip: '일정 수정',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push('/event/edit', extra: master),
            ),
            IconButton(
              tooltip: '일정 삭제',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDelete(context, ref, master),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
      body: AppPageBody(
        child: ListView(
          children: [
            _DetailHeader(event: event),
            const SizedBox(height: 22),
            if (master.repeat != RepeatRule.none)
              _InfoRow(label: '반복', value: _repeatText(master)),
            if (event.hasAlarm)
              _InfoRow(
                label: '알림',
                value: event.alarmMinutesBefore == 0
                    ? '시작 시'
                    : '${event.alarmMinutesBefore}분 전',
              ),
            if (event.description != null && event.description!.isNotEmpty)
              _InfoRow(label: '메모', value: event.description!),
            Container(height: 1, color: DesignTokens.of(context).hairline),
            if (master.reviewText == null && master.reviewPhotoUrl == null) ...[
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () =>
                    _showReviewDialog(context, ref, master, currentUid),
                icon: const Icon(Icons.rate_review_outlined),
                label: const Text('후기 남기기'),
              ),
            ] else ...[
              const SizedBox(height: 14),
              AppSectionCard(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                      child: Row(
                        children: [
                          const Expanded(
                            child: AppSectionHeader(
                              title: '우리의 후기',
                              icon: Icons.auto_awesome_outlined,
                            ),
                          ),
                          TextButton(
                            onPressed: () => _showReviewDialog(
                              context,
                              ref,
                              master,
                              currentUid,
                            ),
                            child: const Text('수정'),
                          ),
                        ],
                      ),
                    ),
                    if (master.reviewPhotoUrl != null)
                      Image.network(
                        master.reviewPhotoUrl!,
                        height: 230,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    if (master.reviewText != null)
                      Padding(
                        padding: const EdgeInsets.all(18),
                        child: Text(
                          master.reviewText!,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            height: 1.55,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            if (master.isProposed &&
                currentUid != null &&
                master.createdByUid != currentUid) ...[
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.tertiaryContainer,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '함께할 일정으로 확정할까요?',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colors.onTertiaryContainer,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: () async {
                              await ref
                                  .read(firestoreServiceProvider)
                                  .updateEvent(
                                    master.copyWith(
                                      status: 'confirmed',
                                      updatedAt: DateTime.now(),
                                    ),
                                    editorUid: currentUid,
                                  );
                              if (context.mounted) context.pop();
                            },
                            child: const Text('수락'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () =>
                                _confirmReject(context, ref, master),
                            child: const Text('거절'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _repeatText(EventModel master) {
    const labels = {
      RepeatRule.daily: '매일',
      RepeatRule.weekly: '매주',
      RepeatRule.monthly: '매월',
      RepeatRule.yearly: '매년',
    };
    final base = '${labels[master.repeat]} 반복';
    if (master.repeatUntil == null) return base;
    return '$base · ${DateFormat('yyyy.MM.dd').format(master.repeatUntil!)}까지';
  }

  Future<void> _showReviewDialog(
    BuildContext context,
    WidgetRef ref,
    EventModel master,
    String? currentUid,
  ) async {
    final reviewController = TextEditingController(
      text: master.reviewText ?? '',
    );
    XFile? pickedPhoto;
    var isSaving = false;

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => PopScope(
            canPop: !isSaving,
            child: AlertDialog(
              title: Text(
                master.reviewText == null && master.reviewPhotoUrl == null
                    ? '후기 남기기'
                    : '후기 수정',
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: reviewController,
                    decoration: const InputDecoration(hintText: '한줄 후기'),
                  ),
                  if (!kIsWeb) ...[
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              final picked = await ImagePicker().pickImage(
                                source: ImageSource.gallery,
                                maxWidth: 1280,
                                imageQuality: 80,
                              );
                              if (picked != null && dialogContext.mounted) {
                                setDialogState(() => pickedPhoto = picked);
                              }
                            },
                      child: const Text('사진 선택'),
                    ),
                    if (pickedPhoto != null) ...[
                      const SizedBox(height: 8),
                      Text(pickedPhoto!.name),
                    ],
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('취소'),
                ),
                FilledButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          setDialogState(() => isSaving = true);
                          final trimmedText = reviewController.text.trim();

                          try {
                            var photoUrl = master.reviewPhotoUrl;
                            if (!kIsWeb && pickedPhoto != null) {
                              final storageRef = FirebaseStorage.instance.ref(
                                'reviews/${master.id}.jpg',
                              );
                              await storageRef.putFile(File(pickedPhoto!.path));
                              photoUrl = await storageRef.getDownloadURL();
                            }

                            await ref
                                .read(firestoreServiceProvider)
                                .updateEvent(
                                  master.copyWith(
                                    reviewText: trimmedText.isEmpty
                                        ? null
                                        : trimmedText,
                                    reviewPhotoUrl: photoUrl,
                                    updatedAt: DateTime.now(),
                                  ),
                                  editorUid: currentUid,
                                );
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                          } catch (_) {
                            if (dialogContext.mounted) {
                              setDialogState(() => isSaving = false);
                            }
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('후기 저장에 실패했습니다')),
                              );
                            }
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('저장'),
                ),
              ],
            ),
          ),
        ),
      );
    } finally {
      reviewController.dispose();
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    EventModel master,
  ) async {
    if (master.repeat == RepeatRule.none) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('일정 삭제'),
          content: const Text('이 일정을 삭제하시겠습니까?'),
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
      await _deleteAll(context, ref, master);
      return;
    }

    // 반복 이벤트: 이 회차만 / 전체
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('반복 일정 삭제'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'one'),
            child: const Text('이 일정만 삭제'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'all'),
            child: const Text('모든 반복 일정 삭제'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
        ],
      ),
    );
    if (choice == null) return;

    if (choice == 'all') {
      await _deleteAll(context, ref, master);
      return;
    }

    // 이 회차만: excludedDates에 추가 (삼성캘린더에는 EXDATE 로 반영)
    final day = calendarDateKey(occurrenceDate ?? event.startDateTime);
    final updated = master.copyWithRepeat(
      repeat: master.repeat,
      repeatUntil: master.repeatUntil,
      excludedDates: {...master.excludedDates, day}.toList(),
    );
    await ref
        .read(firestoreServiceProvider)
        .updateEvent(
          updated,
          editorUid: ref.read(authStateProvider).valueOrNull?.uid,
        );
    // 다음 알림이 이 회차였을 수 있으니 재스케줄
    await NotificationService().cancelAlarm(master.id);
    if (master.hasAlarm) await NotificationService().scheduleAlarm(updated);
    if (context.mounted) context.pop();
  }

  Future<void> _deleteAll(
    BuildContext context,
    WidgetRef ref,
    EventModel master,
  ) async {
    await ref.read(firestoreServiceProvider).deleteEvent(master.id);
    await NotificationService().cancelAlarm(master.id);
    await SamsungCalendarSyncService().syncEventDelete(master.id);
    if (context.mounted) context.pop();
  }

  Future<void> _confirmReject(
    BuildContext context,
    WidgetRef ref,
    EventModel master,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('제안 거절'),
        content: const Text('이 제안을 거절하고 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('거절'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(firestoreServiceProvider).deleteEvent(master.id);
    if (context.mounted) context.pop();
  }
}

/// 캘린더 아젠다와 같은 문법: 일정 색 세로 룰 + 제목, 초대형 가는 날짜 숫자.
class _DetailHeader extends StatelessWidget {
  final EventModel event;
  const _DetailHeader({required this.event});

  @override
  Widget build(BuildContext context) {
    final t = DesignTokens.of(context);
    final start = event.startDateTime;
    final end = event.endDateTime;
    final timeFmt = DateFormat('HH:mm');
    final String when;
    if (event.isAllDay) {
      final multiDay = end != null && !DateUtils.isSameDay(start, end);
      when = multiDay
          ? '종일 · ${DateFormat('M월 d일', 'ko_KR').format(end)}까지'
          : '종일';
    } else {
      when = end != null
          ? '${timeFmt.format(start)} – ${timeFmt.format(end)}'
          : timeFmt.format(start);
    }
    final tags = [
      if (event.isShared) '함께하는 일정',
      if (event.isProposed) '제안된 일정',
    ];

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(width: 3, color: event.colorValue),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [if (event.icon?.isNotEmpty == true) event.icon!, event.title]
                      .join(' '),
                  style: TextStyle(
                    fontSize: 24,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.7,
                    color: t.ink,
                  ),
                ),
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    tags.join(' · '),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: t.accent,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '${start.day}',
                      style: TextStyle(
                        fontSize: 44,
                        height: 0.92,
                        fontWeight: FontWeight.w200,
                        letterSpacing: -1.98,
                        color: t.ink,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('yyyy년 M월 · EEEE', 'ko_KR').format(start),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: t.ink45,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          when,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.3,
                            color: t.ink,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 라벨 · 값 한 줄. 위쪽 가는 선으로만 구분한다.
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final t = DesignTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: t.hairline)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 56,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, height: 1.5, color: t.ink45),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 15,
                height: 1.45,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.2,
                color: t.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
