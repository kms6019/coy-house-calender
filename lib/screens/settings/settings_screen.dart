import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/calendar_provider.dart';

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
          // 사용자 정보
          userAsync.when(
            data: (user) => ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(user?.displayName ?? '-'),
              subtitle: Text(user?.email ?? '-'),
            ),
            loading: () => const ListTile(title: Text('불러오는 중...')),
            error: (error, _) => const SizedBox.shrink(),
          ),
          const Divider(),

          // 파트너 연결 상태
          coupleAsync.when(
            data: (couple) => ListTile(
              leading: Icon(
                couple?.isLinked == true ? Icons.favorite : Icons.link_off,
                color: couple?.isLinked == true ? Colors.pink : Colors.grey,
              ),
              title: const Text('파트너 연결'),
              subtitle: Text(
                couple?.isLinked == true ? '연결됨' : '연결되지 않음',
              ),
              trailing: couple?.isLinked != true
                  ? TextButton(
                      onPressed: () => context.push('/invite'),
                      child: const Text('연결하기'),
                    )
                  : null,
            ),
            loading: () => const ListTile(title: Text('불러오는 중...')),
            error: (error, _) => const SizedBox.shrink(),
          ),
          const Divider(),

          // 로그아웃
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('로그아웃', style: TextStyle(color: Colors.red)),
            onTap: () async {
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
                await ref.read(authServiceProvider).signOut();
                if (context.mounted) context.go('/login');
              }
            },
          ),
        ],
      ),
    );
  }
}
