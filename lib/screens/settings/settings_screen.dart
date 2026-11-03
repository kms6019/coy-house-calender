import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../models/couple_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/calendar_provider.dart';
import '../../services/device_sync_prefs.dart';
import '../../services/holiday_prefs.dart';
import '../../services/notification_service.dart';
import '../../services/samsung_calendar_sync_service.dart';
import '../../services/widget_service.dart';
import '../../theme/couple_palette.dart';
import '../../theme/app_theme.dart' show kPrimaryPurple;
import '../../widgets/app_surface.dart';
import '../../widgets/update_prompt.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final userAsync = ref.watch(currentUserModelProvider);
    final coupleAsync = ref.watch(coupleStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: AppPageBody(
        child: ListView(
          children: [
            Text('우리에게 맞게', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              '둘이 함께 쓰는 달력을 편안하게 설정해 보세요.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 22),
            _SettingsGroup(
              title: '계정과 연결',
              icon: Icons.people_alt_outlined,
              children: [
                userAsync.when(
                  data: (user) => ListTile(
                    leading: CircleAvatar(
                      backgroundColor: colors.primaryContainer,
                      child: Text(
                        user?.displayName.isNotEmpty == true
                            ? user!.displayName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: colors.onPrimaryContainer,
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
                coupleAsync.when(
                  data: (couple) {
                    if (couple == null) {
                      return ListTile(
                        leading: Icon(
                          Icons.favorite_border,
                          color: colors.onSurfaceVariant,
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
                      return Column(
                        children: [
                          ListTile(
                            leading: Icon(
                              Icons.favorite_border,
                              color: colors.onSurfaceVariant,
                            ),
                            title: const Text('파트너 연결 대기 중'),
                            subtitle: Text(
                              '초대 코드: ${couple.inviteCode}\n파트너가 이 코드를 입력하면 연결됩니다',
                            ),
                            isThreeLine: true,
                            trailing: IconButton(
                              tooltip: '초대 코드 복사',
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
                            padding: const EdgeInsets.only(left: 64, bottom: 8),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: () =>
                                    _enterPartnerCode(context, ref),
                                icon: const Icon(Icons.keyboard, size: 18),
                                label: const Text('파트너 코드 입력하기'),
                              ),
                            ),
                          ),
                        ],
                      );
                    }
                    final myUid = ref.read(authStateProvider).valueOrNull?.uid;
                    final isOwner = couple.ownerUid == myUid;
                    final myColor = isOwner
                        ? couple.ownerColorValue
                        : couple.partnerColorValue;
                    final colorForeground =
                        ThemeData.estimateBrightnessForColor(myColor) ==
                            Brightness.dark
                        ? colors.surface
                        : colors.onSurface;
                    return Column(
                      children: [
                        ListTile(
                          leading: Icon(Icons.favorite, color: colors.primary),
                          title: const Text('파트너 연결'),
                          subtitle: const Text('두 사람의 캘린더가 연결되어 있어요'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InkWell(
                                onTap: myUid == null
                                    ? null
                                    : () => _pickMyColor(
                                        context,
                                        ref,
                                        couple,
                                        myUid,
                                      ),
                                customBorder: const CircleBorder(),
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: myColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.edit,
                                    size: 14,
                                    color: colorForeground,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isOwner ? '방장' : '파트너',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isOwner)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(64, 0, 16, 12),
                            child: Row(
                              children: [
                                Text(
                                  '초대 코드',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  couple.inviteCode,
                                  style: theme.textTheme.labelLarge?.copyWith(
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
              ],
            ),
            const SizedBox(height: 18),
            _SettingsGroup(
              title: '함께 쓰기',
              icon: Icons.favorite_outline,
              children: [
                ListTile(
                  leading: const Icon(Icons.cake_outlined),
                  title: const Text('기념일 관리'),
                  subtitle: const Text('D-day와 매년 돌아오는 날'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/anniversaries'),
                ),
                ListTile(
                  leading: const Icon(Icons.checklist),
                  title: const Text('위시리스트'),
                  subtitle: const Text('함께하고 싶은 데이트 모음'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/wishlist'),
                ),
                ListTile(
                  leading: const Icon(Icons.bar_chart_outlined),
                  title: const Text('월간 리포트'),
                  subtitle: const Text('이번 달 둘의 일정 돌아보기'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/report'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const _SettingsGroup(
              title: '화면과 테마',
              icon: Icons.palette_outlined,
              children: [_ThemeSection()],
            ),
            const SizedBox(height: 18),
            _SettingsGroup(
              title: '캘린더 연동',
              icon: Icons.sync_alt,
              children: [
                ListTile(
                  leading: const Icon(Icons.download_outlined),
                  title: const Text('기기 캘린더 가져오기'),
                  subtitle: const Text('앞으로 90일의 일정을 선택해 가져오기'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/import'),
                ),
                const _ManualSyncSection(),
                const _HolidaySection(),
              ],
            ),
            const SizedBox(height: 18),
            _SettingsGroup(
              title: '알림',
              icon: Icons.notifications_outlined,
              children: [
                const _BriefingSection(),
                ListTile(
                  leading: const Icon(Icons.history),
                  title: const Text('알림 기록'),
                  subtitle: const Text('일정 알람과 파트너 알림 모아보기'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/notifications'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _SettingsGroup(
              title: '앱 정보',
              icon: Icons.info_outline,
              children: [
                const _VersionTile(),
                ListTile(
                  leading: Icon(Icons.logout, color: colors.error),
                  title: Text('로그아웃', style: TextStyle(color: colors.error)),
                  onTap: () => _confirmLogout(context, ref),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
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
                            color:
                                ThemeData.estimateBrightnessForColor(
                                      Color(c),
                                    ) ==
                                    Brightness.dark
                                ? Theme.of(ctx).colorScheme.surface
                                : Theme.of(ctx).colorScheme.onSurface,
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
  bool _syncEnabled = true;

  @override
  void initState() {
    super.initState();
    DeviceSyncPrefs.isEnabled().then((v) {
      if (mounted) setState(() => _syncEnabled = v);
    });
  }

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
        msg.write('\n${s.diagnostics}');
        if (s.firstError != null) msg.write('\n${s.firstError}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$msg'),
            duration: const Duration(seconds: 15),
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

  Future<void> _diagnose() async {
    setState(() => _busy = true);
    final report = await SamsungCalendarSyncService().describeCalendars();
    if (!mounted) return;
    setState(() => _busy = false);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('기기 캘린더 진단'),
        content: SingleChildScrollView(
          child: SelectableText(
            report,
            style: const TextStyle(fontSize: 12, height: 1.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: report));
              Navigator.of(dialogContext).pop();
            },
            child: const Text('복사'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  /// 중복이 쌓였을 때의 확실한 복구: 전용 캘린더를 지우고 다시 만든다.
  Future<void> _reset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('삼성캘린더 초기화'),
        content: const Text(
          '기기의 CoyHouseCalender 캘린더를 통째로 지우고 다시 만듭니다.\n\n'
          '쌓인 중복 일정이 전부 사라지고, 앱의 일정만 한 번씩 새로 들어갑니다. '
          '다른 캘린더(구글·삼성 기본 등)는 건드리지 않습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('초기화'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      final events = ref.read(eventsStreamProvider).valueOrNull ?? [];
      final service = SamsungCalendarSyncService();
      // 앱이 만든 캘린더를 전부 지우고(사본까지 통째로) 한 번만 다시 만든다.
      final removed = await service.deleteAppCalendars();
      final s = await service.syncAll(events);
      if (!mounted) return;
      final msg = StringBuffer(
        '초기화: 캘린더 $removed개 삭제 · 일정 ${s.created}건 재생성',
      );
      if (s.firstError != null) msg.write('\n${s.firstError}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$msg'), duration: const Duration(seconds: 12)),
      );
    } catch (e) {
      debugPrint('[Settings] reset error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('초기화에 실패했습니다')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final spinner = _busy
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : null;
    return Column(
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.event_repeat_outlined),
          title: const Text('기기 캘린더 동기화'),
          subtitle: const Text('끄면 삼성캘린더에 일정을 쓰지 않습니다'),
          value: _syncEnabled,
          onChanged: _busy
              ? null
              : (v) async {
                  await DeviceSyncPrefs.setEnabled(v);
                  if (mounted) setState(() => _syncEnabled = v);
                },
        ),
        ListTile(
          enabled: _syncEnabled,
          leading: const Icon(Icons.sync),
          title: const Text('삼성캘린더 지금 동기화'),
          subtitle: const Text('모든 일정을 기기 캘린더·위젯에 다시 반영'),
          trailing: spinner,
          onTap: (_busy || !_syncEnabled) ? null : _sync,
        ),
        ListTile(
          leading: const Icon(Icons.bug_report_outlined),
          title: const Text('기기 캘린더 진단'),
          subtitle: const Text('앱이 어떤 캘린더를 보고 있는지 확인'),
          onTap: _busy ? null : _diagnose,
        ),
        ListTile(
          enabled: _syncEnabled,
          leading: const Icon(Icons.cleaning_services_outlined),
          title: const Text('삼성캘린더 초기화'),
          subtitle: const Text('중복이 쌓였을 때 — 전용 캘린더를 지우고 다시 만듭니다'),
          trailing: spinner,
          onTap: (_busy || !_syncEnabled) ? null : _reset,
        ),
      ],
    );
  }
}

class _ThemeSection extends ConsumerWidget {
  const _ThemeSection();

  Future<void> _pickColor(
    BuildContext context,
    WidgetRef ref,
    int? current,
  ) async {
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
                  decoration: BoxDecoration(
                    color: Color(c),
                    shape: BoxShape.circle,
                  ),
                  child: isMine
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
    if (picked == null) return;
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    await ref.read(firestoreServiceProvider).updateUserSettings(uid, {
      'themeSeedColor': picked,
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserModelProvider).valueOrNull;
    final mode = user?.themeMode ?? 'system';
    final seedColor = user?.themeSeedColor ?? kPrimaryPurple.toARGB32();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ListTile(
          leading: Icon(Icons.brightness_6_outlined),
          title: Text('화면 모드'),
          subtitle: Text('시스템 설정을 따르거나 직접 선택'),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 'system', label: Text('시스템')),
              ButtonSegment(value: 'light', label: Text('라이트')),
              ButtonSegment(value: 'dark', label: Text('다크')),
            ],
            selected: {mode},
            onSelectionChanged: (selection) async {
              final uid = ref.read(authStateProvider).valueOrNull?.uid;
              if (uid == null) return;
              await ref.read(firestoreServiceProvider).updateUserSettings(uid, {
                'themeMode': selection.first,
              });
            },
          ),
        ),
        ListTile(
          leading: const Icon(Icons.palette_outlined),
          title: const Text('테마 색상'),
          subtitle: const Text('앱 전체 분위기를 바꾸는 seed 색상'),
          trailing: InkWell(
            onTap: () => _pickColor(context, ref, user?.themeSeedColor),
            customBorder: const CircleBorder(),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Color(seedColor),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(title: title, icon: icon),
        Card(
          child: Column(
            children: [
              for (var index = 0; index < children.length; index++) ...[
                children[index],
                if (index != children.length - 1)
                  const Divider(indent: 16, endIndent: 16),
              ],
            ],
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
          await ref.read(firestoreServiceProvider).updateUserSettings(uid, {
            'showKoreanHolidays': value,
          });

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
                initialTime: TimeOfDay(
                  hour: user.briefingHour,
                  minute: user.briefingMinute,
                ),
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

/// 설치된 버전 표시 + (안드로이드) 업데이트 확인 버튼.
class _VersionTile extends StatelessWidget {
  const _VersionTile();

  @override
  Widget build(BuildContext context) {
    final canUpdate = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final info = snapshot.data;
        return ListTile(
          leading: const Icon(Icons.apps_outlined),
          title: const Text('버전'),
          subtitle: Text(
            info == null ? '' : '${info.version} (${info.buildNumber})',
          ),
          trailing: canUpdate
              ? TextButton(
                  onPressed: () => checkForUpdateManually(context),
                  child: const Text('업데이트 확인'),
                )
              : null,
        );
      },
    );
  }
}
