import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/wish_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/calendar_provider.dart';
import '../../widgets/app_surface.dart';

class WishlistScreen extends ConsumerWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wishesAsync = ref.watch(wishesStreamProvider);
    final couple = ref.watch(coupleStreamProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('데이트 위시리스트')),
      body: couple == null
          ? const AppEmptyState(
              icon: Icons.favorite_border,
              title: '파트너 연결 후 사용할 수 있습니다',
              message: '함께 하고 싶은 일을 둘만의 목록에 담아 보세요.',
            )
          : wishesAsync.when(
              data: (wishes) {
                if (wishes.isEmpty) {
                  return AppEmptyState(
                    icon: Icons.favorite_outline,
                    title: '함께 하고 싶은 일이 있나요?',
                    message: '맛집, 여행, 소소한 데이트까지 무엇이든 좋아요.',
                    action: FilledButton.tonalIcon(
                      onPressed: () => _showForm(context, ref),
                      icon: const Icon(Icons.add),
                      label: const Text('첫 위시 추가'),
                    ),
                  );
                }
                final sorted = sortWishes(wishes);
                final done = sorted.where((wish) => wish.done).length;
                final theme = Theme.of(context);
                final colors = theme.colorScheme;
                return AppPageBody(
                  child: ListView.separated(
                    itemCount: sorted.length + 1,
                    separatorBuilder: (_, index) =>
                        SizedBox(height: index == 0 ? 16 : 9),
                    itemBuilder: (context, i) {
                      if (i == 0) {
                        return Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: colors.primaryContainer,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '우리의 다음 데이트',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: colors.onPrimaryContainer,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '$done개 완료 · ${sorted.length - done}개 기다리는 중',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colors.onPrimaryContainer,
                                ),
                              ),
                              const SizedBox(height: 14),
                              LinearProgressIndicator(
                                value: done / sorted.length,
                                minHeight: 9,
                                color: colors.primary,
                                backgroundColor: colors.surface.withValues(
                                  alpha: 0.55,
                                ),
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ],
                          ),
                        );
                      }
                      final w = sorted[i - 1];
                      return Card(
                        child: ListTile(
                          leading: Checkbox(
                            value: w.done,
                            onChanged: (v) => ref
                                .read(firestoreServiceProvider)
                                .updateWish(w.copyWith(done: v ?? false)),
                          ),
                          title: Text(
                            w.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              decoration: w.done
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: w.done
                                  ? colors.onSurfaceVariant
                                  : colors.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: (w.memo?.isNotEmpty == true)
                              ? Text(
                                  w.memo!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : null,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.event_outlined,
                                  size: 20,
                                ),
                                tooltip: '일정으로',
                                onPressed: () => context.push(
                                  '/event/new',
                                  extra: {'title': w.title},
                                ),
                              ),
                              IconButton(
                                tooltip: '삭제',
                                icon: Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                  color: colors.onSurfaceVariant,
                                ),
                                onPressed: () =>
                                    _confirmDelete(context, ref, w),
                              ),
                            ],
                          ),
                          onTap: () => _showForm(context, ref, existing: w),
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, st) => const Center(child: Text('불러오지 못했습니다')),
            ),
      floatingActionButton: couple == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showForm(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('위시 추가'),
            ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    WishModel wish,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('위시 삭제'),
        content: Text("'${wish.title}'을(를) 삭제할까요?"),
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
    if (confirmed == true) {
      await ref.read(firestoreServiceProvider).deleteWish(wish.id);
    }
  }

  Future<void> _showForm(
    BuildContext context,
    WidgetRef ref, {
    WishModel? existing,
  }) async {
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
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              if (titleCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('제목을 입력하세요')));
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
          await fs.addWish(
            WishModel(
              id: '',
              coupleId: couple.coupleId,
              createdByUid: uid,
              title: title,
              memo: memo.isEmpty ? null : memo,
              createdAt: DateTime.now(),
            ),
          );
        }
      }
    } finally {
      titleCtrl.dispose();
      memoCtrl.dispose();
    }
  }
}
