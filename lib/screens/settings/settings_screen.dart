import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/couple_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/calendar_provider.dart';
import '../../services/holiday_prefs.dart';
import '../../services/notification_service.dart';
import '../../services/samsung_calendar_sync_service.dart';
import '../../services/widget_service.dart';
import '../../theme/couple_palette.dart';
import '../../theme/app_theme.dart' show kPrimaryPurple;

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserModelProvider);
    final coupleAsync = ref.watch(coupleStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        children: [
          // 내 계정 정보
          userAsync.when(
            data: (user) => ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Text(
                  user?.displayName.isNotEmpty == true
                      ? user!.displayName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                user?.displayName ?? '-',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(user?.email ?? '-'),
            ),
            loading: () => const ListTile(
              leading: CircleAvatar(child: Icon(Icons.person)),
              title: Text('불러오는 중...'),
            ),
            error: (err, st) => const SizedBox.shrink(),
          ),
          const Divider(),

          // 파트너 연결 상태
          coupleAsync.when(
            data: (couple) {
              if (couple == null) {
                return ListTile(
                  leading: const Icon(
                    Icons.favorite_border,
                    color: Colors.grey,
                  ),
                  title: const Text('파트너 연결'),
                  subtitle: const Text('아직 파트너와 연결되지 않았습니다'),
                  trailing: TextButton(
                    onPressed: () => context.push('/invite'),
                    child: const Text('연결하기'),
                  ),
                );
              }
              if (!couple.isLinked) {
                // 커플 생성됨·파트너 대기 중: /invite는 coupleId 있으면 튕기므로
                // 초대 코드 표시 + 상대 코드 입력을 여기서 처리한다
                return Column(
                  children: [
                    ListTile(
                      leading: const Icon(
                        Icons.favorite_border,
                        color: Colors.grey,
                      ),
                      title: const Text('파트너 연결 대기 중'),
                      subtitle: Text(
                        '초대 코드: ${couple.inviteCode}\n파트너가 이 코드를 입력하면 연결됩니다',
                      ),
                      isThreeLine: true,
                      trailing: IconButton(
                        icon: const Icon(Icons.copy, size: 20),
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: couple.inviteCode),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('코드가 복사되었습니다')),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 72, bottom: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => _enterPartnerCode(context, ref),
                          icon: const Icon(Icons.keyboard, size: 18),
                          label: const Text('파트너 코드 입력하기'),
                        ),
                      ),
                    ),
                  ],
                );
              }
              // 연결됨 상태
              final myUid = ref.read(authStateProvider).valueOrNull?.uid;
              final isOwner = couple.ownerUid == myUid;
              return Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.favorite, color: Colors.pink),
                    title: const Text('파트너 연결'),
                    subtitle: const Text('연결됨'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: myUid == null
                              ? null
                              : () => _pickMyColor(context, ref, couple, myUid),
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: isOwner
                                  ? couple.ownerColorValue
                                  : couple.partnerColorValue,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.edit,
                              size: 12,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isOwner ? '방장' : '파트너',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 초대 코드 표시 (방장만)
                  if (isOwner && !couple.isLinked == false)
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 72,
                        right: 16,
                        bottom: 8,
                      ),
                      child: Row(
                        children: [
                          Text(
                            '초대 코드: ',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            couple.inviteCode,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
            loading: () => const ListTile(
              leading: Icon(Icons.favorite_border),
              title: Text('불러오는 중...'),
            ),
            error: (err, st) => const SizedBox.shrink(),
          ),
          const Divider(),

          // 기념일 관리
          ListTile(
            leading: const Icon(Icons.cake_outlined),
            title: const Text('기념일 관리'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/anniversaries'),
          ),
          const Divider(),

          // 위시리스트
          ListTile(
            leading: const Icon(Icons.checklist),
            title: const Text('위시리스트'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/wishlist'),
          ),
          const Divider(),

          // 테마
          const _ThemeSection(),
          const Divider(),

          // 월간 리포트
          ListTile(
            leading: const Icon(Icons.bar_chart_outlined),
            title: const Text('월간 리포트'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/report'),
          ),
          const Divider(),

          // 기기 캘린더 가져오기
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('기기 캘린더 가져오기'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/import'),
          ),
          const Divider(),

          // 삼성캘린더 수동 동기화
          const _ManualSyncSection(),
          const Divider(),

          // 대한민국 공휴일
          const _HolidaySection(),
          const Divider(),

          // 아침 브리핑
          const _BriefingSection(),
          const Divider(),

          // 앱 정보
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('버전'),
            trailing: Text('1.0.0', style: TextStyle(color: Colors.grey)),
          ),
          const Divider(),

          // 로그아웃
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('로그아웃', style: TextStyle(color: Colors.red)),
            onTap: () => _confirmLogout(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _enterPartnerCode(BuildContext context, WidgetRef ref) async {
    final codeCtrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('파트너 코드 입력'),
        content: TextField(
          controller: codeCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '예) AB12CD',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.characters,
          maxLength: 6,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, codeCtrl.text.trim()),
            child: const Text('연결'),
          ),
        ],
      ),
    );
    codeCtrl.dispose();
    if (code == null || code.length != 6) {
      if (code != null && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('6자리 코드를 입력하세요')));
      }
      return;
    }

    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    try {
      final joined = await ref
          .read(firestoreServiceProvider)
          .joinByInviteCode(code, uid);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(joined != null ? '파트너와 연결되었습니다!' : '유효하지 않은 코드입니다'),
        ),
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('연결에 실패했습니다')));
      }
    }
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('로그아웃 하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await NotificationService().cancelAll();
      await ref.read(authServiceProvider).signOut();
      if (context.mounted) context.go('/login');
    }
  }

  Future<void> _pickMyColor(
    BuildContext context,
    WidgetRef ref,
    CoupleModel couple,
    String myUid,
  ) async {
    final isOwner = couple.ownerUid == myUid;
    final myColor = isOwner ? couple.ownerColor : couple.partnerColor;
    final partnerColor = isOwner ? couple.partnerColor : couple.ownerColor;

    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('내 색상'),
        content: SizedBox(
          width: 280,
          child: GridView.count(
            shrinkWrap: true,
            crossAxisCount: 4,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: kCouplePalette.map((c) {
              final isMine = c == myColor;
              final isPartner = c == partnerColor;
              return InkWell(
                onTap: isPartner ? null : () => Navigator.pop(ctx, c),
                customBorder: const CircleBorder(),
                child: Opacity(
                  opacity: isPartner ? 0.25 : 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Color(c),
                      shape: BoxShape.circle,
                    ),
                    child: isMine
                        ? Icon(
                            Icons.check,
                            color: Color(c).computeLuminance() > 0.5
                                ? Colors.black54
                                : Colors.white,
                          )
                        : null,
                  ),
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

    if (picked == null || picked == myColor) return;
    try {
      await ref
          .read(firestoreServiceProvider)
          .updateMyColor(couple: couple, myUid: myUid, color: picked);
    } catch (e) {
      debugPrint('[Settings] updateMyColor error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('색상 변경에 실패했습니다.')));
      }
    }
  }
}

class _ManualSyncSection extends ConsumerStatefulWidget {
  const _ManualSyncSection();

  @override
  ConsumerState<_ManualSyncSection> createState() => _ManualSyncSectionState();
}

class _ManualSyncSectionState extends ConsumerState<_ManualSyncSection> {
  bool _busy = false;

  Future<void> _sync() async {
    setState(() => _busy = true);
    try {
      final events = ref.read(eventsStreamProvider).valueOrNull ?? [];
      final anniversaries =
          ref.read(coupleStreamProvider).valueOrNull?.anniversaries ?? const [];
      final s = await SamsungCalendarSyncService().syncAll(events);
      await WidgetService.update(events, anniversaries: anniversaries);
      if (mounted) {
        final msg = StringBuffer(
          '동기화: 생성 ${s.created} · 갱신 ${s.updated} · 삭제 ${s.deleted} · 실패 ${s.failed}',
        );
        if (s.firstError != null) msg.write('\n${s.firstError}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$msg'),
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } catch (e) {
      debugPrint('[Settings] manual sync error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('동기화에 실패했습니다')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.sync),
      title: const Text('삼성캘린더 지금 동기화'),
      subtitle: const Text('모든 일정을 기기 캘린더·위젯에 다시 반영'),
      trailing: _busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      onTap: _busy ? null : _sync,
    );
  }
}

class _ThemeSection extends ConsumerWidget {
  const _ThemeSection();

  Future<void> _pickColor(BuildContext context, WidgetRef ref, int? current) async {
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('테마 색상'),
        content: SizedBox(
          width: 280,
          child: GridView.count(
            shrinkWrap: true,
            crossAxisCount: 4,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: kCouplePalette.map((c) {
              final isMine = c == current;
              return InkWell(
                onTap: () => Navigator.pop(ctx, c),
                customBorder: const CircleBorder(),
                child: Container(
                  decoration: BoxDecoration(color: Color(c), shape: BoxShape.circle),
                  child: isMine
                      ? Icon(
                          Icons.check,
                          color: Color(c).computeLuminance() > 0.5
                              ? Colors.black54
                              : Colors.white,
                        )
                      : null,
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
        ],
      ),
    );
    if (picked == null) return;
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    await ref
        .read(firestoreServiceProvider)
        .updateUserSettings(uid, {'themeSeedColor': picked});
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserModelProvider).valueOrNull;
    final mode = user?.themeMode ?? 'system';
    final seedColor = user?.themeSeedColor ?? kPrimaryPurple.toARGB32();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: const Icon(Icons.palette_outlined),
          title: const Text('테마'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'system', label: Text('시스템')),
              ButtonSegment(value: 'light', label: Text('라이트')),
              ButtonSegment(value: 'dark', label: Text('다크')),
            ],
            selected: {mode},
            onSelectionChanged: (selection) async {
              final uid = ref.read(authStateProvider).valueOrNull?.uid;
              if (uid == null) return;
              await ref
                  .read(firestoreServiceProvider)
                  .updateUserSettings(uid, {'themeMode': selection.first});
            },
          ),
        ),
        ListTile(
          contentPadding: const EdgeInsets.only(left: 16, right: 16, top: 8),
          title: const Text('색상'),
          trailing: GestureDetector(
            onTap: () => _pickColor(context, ref, user?.themeSeedColor),
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(color: Color(seedColor), shape: BoxShape.circle),
            ),
          ),
        ),
      ],
    );
  }
}

class _HolidaySection extends ConsumerWidget {
  const _HolidaySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserModelProvider);
    return userAsync.when(
      data: (user) => SwitchListTile(
        secondary: const Icon(Icons.flag_outlined),
        title: const Text('대한민국 공휴일 표시'),
        subtitle: const Text('법정·대체·임시공휴일과 선거일을 달력에 표시'),
        value: user?.showKoreanHolidays ?? true,
        onChanged: (value) async {
          final uid = ref.read(authStateProvider).valueOrNull?.uid;
          if (uid == null) return;
          await HolidayPrefs.saveEnabled(value);
          await ref
              .read(firestoreServiceProvider)
              .updateUserSettings(uid, {'showKoreanHolidays': value});

          final events = ref.read(eventsStreamProvider).valueOrNull ?? [];
          final anniversaries =
              ref.read(coupleStreamProvider).valueOrNull?.anniversaries ??
              const [];
          await WidgetService.update(events, anniversaries: anniversaries);
        },
      ),
      loading: () => const ListTile(
        leading: Icon(Icons.flag_outlined),
        title: Text('대한민국 공휴일 표시'),
        trailing: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _BriefingSection extends ConsumerWidget {
  const _BriefingSection();

  Future<void> _apply(
    WidgetRef ref, {
    required bool enabled,
    required int hour,
    required int minute,
  }) async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    await ref.read(firestoreServiceProvider).updateUserSettings(uid, {
      'briefingEnabled': enabled,
      'briefingHour': hour,
      'briefingMinute': minute,
    });
    final events = ref.read(eventsStreamProvider).valueOrNull ?? [];
    await NotificationService().scheduleBriefings(
      events: events,
      enabled: enabled,
      hour: hour,
      minute: minute,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserModelProvider).valueOrNull;
    if (user == null) return const SizedBox.shrink();
    return Column(
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.wb_sunny_outlined),
          title: const Text('아침 브리핑'),
          subtitle: const Text('매일 아침 오늘 일정 요약 알림 (일정 없는 날 제외)'),
          value: user.briefingEnabled,
          onChanged: (v) => _apply(
            ref,
            enabled: v,
            hour: user.briefingHour,
            minute: user.briefingMinute,
          ),
        ),
        if (user.briefingEnabled)
          ListTile(
            contentPadding: const EdgeInsets.only(left: 72, right: 16),
            title: const Text('브리핑 시간'),
            trailing: Text(
              '${user.briefingHour.toString().padLeft(2, '0')}:${user.briefingMinute.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 16),
            ),
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime:
                    TimeOfDay(hour: user.briefingHour, minute: user.briefingMinute),
              );
              if (picked != null) {
                _apply(
                  ref,
                  enabled: true,
                  hour: picked.hour,
                  minute: picked.minute,
                );
              }
            },
          ),
      ],
    );
  }
}
