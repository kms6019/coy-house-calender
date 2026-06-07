import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/calendar_provider.dart';
import '../../services/notification_service.dart';

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
              if (couple == null || !couple.isLinked) {
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
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: isOwner
                                ? couple.ownerColorValue
                                : couple.partnerColorValue,
                            shape: BoxShape.circle,
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
}
