import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/couple_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/calendar_provider.dart';
import '../../services/briefing_prefs.dart';
import '../../services/notification_service.dart';
import '../../theme/couple_palette.dart';

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
              title: Text(user?.displayName ?? '-',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
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
                  leading: const Icon(Icons.favorite_border, color: Colors.grey),
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
                      leading:
                          const Icon(Icons.favorite_border, color: Colors.grey),
                      title: const Text('파트너 연결 대기 중'),
                      subtitle: Text(
                          '초대 코드: ${couple.inviteCode}\n파트너가 이 코드를 입력하면 연결됩니다'),
                      isThreeLine: true,
                      trailing: IconButton(
                        icon: const Icon(Icons.copy, size: 20),
                        onPressed: () {
                          Clipboard.setData(
                              ClipboardData(text: couple.inviteCode));
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
                            child: const Icon(Icons.edit,
                                size: 12, color: Colors.white70),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isOwner ? '방장' : '파트너',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  // 초대 코드 표시 (방장만)
                  if (isOwner && !couple.isLinked == false)
                    Padding(
                      padding: const EdgeInsets.only(left: 72, right: 16, bottom: 8),
                      child: Row(
                        children: [
                          Text('초대 코드: ',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[600])),
                          Text(couple.inviteCode,
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold,
                                  letterSpacing: 2)),
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
              onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('6자리 코드를 입력하세요')),
        );
      }
      return;
    }

    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    try {
      final joined =
          await ref.read(firestoreServiceProvider).joinByInviteCode(code, uid);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(joined != null
                ? '파트너와 연결되었습니다!'
                : '유효하지 않은 코드입니다')),
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('연결에 실패했습니다')),
        );
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
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('로그아웃')),
        ],
      ),
    );
    if (confirmed == true) {
      await NotificationService().cancelAll();
      await ref.read(authServiceProvider).signOut();
      if (context.mounted) context.go('/login');
    }
  }

  Future<void> _pickMyColor(BuildContext context, WidgetRef ref,
      CoupleModel couple, String myUid) async {
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
                        ? const Icon(Icons.check, color: Colors.white)
                        : null,
                  ),
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

    if (picked == null || picked == myColor) return;
    try {
      await ref
          .read(firestoreServiceProvider)
          .updateMyColor(couple: couple, myUid: myUid, color: picked);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('일부 일정 색이 변경되지 않았습니다.')),
        );
      }
    }
  }
}

class _BriefingSection extends ConsumerStatefulWidget {
  const _BriefingSection();

  @override
  ConsumerState<_BriefingSection> createState() => _BriefingSectionState();
}

class _BriefingSectionState extends ConsumerState<_BriefingSection> {
  BriefingPrefs? _prefs;

  @override
  void initState() {
    super.initState();
    BriefingPrefs.load().then((p) {
      if (mounted) setState(() => _prefs = p);
    });
  }

  Future<void> _apply({required bool enabled, int? hour, int? minute}) async {
    final h = hour ?? _prefs?.hour ?? 8;
    final m = minute ?? _prefs?.minute ?? 0;
    await BriefingPrefs.save(enabled: enabled, hour: h, minute: m);
    if (!mounted) return;
    setState(() => _prefs = BriefingPrefs(enabled: enabled, hour: h, minute: m));
    final events = ref.read(eventsStreamProvider).valueOrNull ?? [];
    await NotificationService().scheduleBriefings(
      events: events,
      enabled: enabled,
      hour: h,
      minute: m,
    );
  }

  @override
  Widget build(BuildContext context) {
    final prefs = _prefs;
    if (prefs == null) return const SizedBox.shrink();
    return Column(
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.wb_sunny_outlined),
          title: const Text('아침 브리핑'),
          subtitle: const Text('매일 아침 오늘 일정 요약 알림 (일정 없는 날 제외)'),
          value: prefs.enabled,
          onChanged: (v) => _apply(enabled: v),
        ),
        if (prefs.enabled)
          ListTile(
            contentPadding: const EdgeInsets.only(left: 72, right: 16),
            title: const Text('브리핑 시간'),
            trailing: Text(
              '${prefs.hour.toString().padLeft(2, '0')}:${prefs.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 16),
            ),
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime:
                    TimeOfDay(hour: prefs.hour, minute: prefs.minute),
              );
              if (picked != null) {
                _apply(
                    enabled: true, hour: picked.hour, minute: picked.minute);
              }
            },
          ),
      ],
    );
  }
}
