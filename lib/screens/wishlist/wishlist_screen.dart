import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/wish_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/calendar_provider.dart';

class WishlistScreen extends ConsumerWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wishesAsync = ref.watch(wishesStreamProvider);
    final couple = ref.watch(coupleStreamProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('데이트 위시리스트')),
      body: couple == null
          ? const Center(child: Text('파트너 연결 후 사용할 수 있습니다'))
          : wishesAsync.when(
              data: (wishes) {
                if (wishes.isEmpty) {
                  return Center(
                    child: Text('하고 싶은 것을 적어보세요',
                        style: TextStyle(color: Colors.grey[400])),
                  );
                }
                final sorted = sortWishes(wishes);
                return ListView.separated(
                  itemCount: sorted.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final w = sorted[i];
                    return ListTile(
                      leading: Checkbox(
                        value: w.done,
                        onChanged: (v) => ref
                            .read(firestoreServiceProvider)
                            .updateWish(w.copyWith(done: v ?? false)),
                      ),
                      title: Text(
                        w.title,
                        style: w.done
                            ? const TextStyle(
                                decoration: TextDecoration.lineThrough,
                                color: Colors.grey)
                            : null,
                      ),
                      subtitle: (w.memo?.isNotEmpty == true)
                          ? Text(w.memo!,
                              maxLines: 1, overflow: TextOverflow.ellipsis)
                          : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.event_outlined, size: 20),
                            tooltip: '일정으로',
                            onPressed: () => context.push('/event/new',
                                extra: {'title': w.title}),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                size: 20, color: Colors.grey),
                            onPressed: () => _confirmDelete(context, ref, w),
                          ),
                        ],
                      ),
                      onTap: () => _showForm(context, ref, existing: w),
                    );
                  },
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (err, st) =>
                  const Center(child: Text('불러오지 못했습니다')),
            ),
      floatingActionButton: couple == null
          ? null
          : FloatingActionButton(
              onPressed: () => _showForm(context, ref),
              child: const Icon(Icons.add),
            ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, WishModel wish) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('위시 삭제'),
        content: Text("'${wish.title}'을(를) 삭제할까요?"),
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
    if (confirmed == true) {
      await ref.read(firestoreServiceProvider).deleteWish(wish.id);
    }
  }

  Future<void> _showForm(BuildContext context, WidgetRef ref,
      {WishModel? existing}) async {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final memoCtrl = TextEditingController(text: existing?.memo ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? '위시 추가' : '위시 수정'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: '제목'),
            ),
            TextField(
              controller: memoCtrl,
              decoration: const InputDecoration(labelText: '메모 (선택)'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          FilledButton(
            onPressed: () {
              if (titleCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('제목을 입력하세요')),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );

    try {
      if (saved == true) {
        final title = titleCtrl.text.trim();
        final memo = memoCtrl.text.trim();
        final fs = ref.read(firestoreServiceProvider);
        if (existing != null) {
          // copyWith는 null 병합이라 빈 문자열로 저장 (subtitle 가드가 미표시 처리)
          await fs.updateWish(existing.copyWith(title: title, memo: memo));
        } else {
          final uid = ref.read(authStateProvider).valueOrNull?.uid;
          final couple = ref.read(coupleStreamProvider).valueOrNull;
          if (uid == null || couple == null) return;
          await fs.addWish(WishModel(
            id: '',
            coupleId: couple.coupleId,
            createdByUid: uid,
            title: title,
            memo: memo.isEmpty ? null : memo,
            createdAt: DateTime.now(),
          ));
        }
      }
    } finally {
      titleCtrl.dispose();
      memoCtrl.dispose();
    }
  }
}
