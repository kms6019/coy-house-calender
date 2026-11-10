import 'package:flutter/material.dart';
import '../../models/anniversary_model.dart';
import '../../utils/dday_utils.dart';

class AnniversaryChips extends StatelessWidget {
  final List<AnniversaryModel> anniversaries;

  /// 한 사람의 기념일은 그 사람 색으로 (uid → 색)
  final Map<String, int> ownerColors;

  const AnniversaryChips({
    super.key,
    required this.anniversaries,
    this.ownerColors = const {},
  });

  @override
  Widget build(BuildContext context) {
    if (anniversaries.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final now = DateTime.now();
    final sorted = sortedForDisplay(anniversaries, now);
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: sorted.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final a = sorted[i];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: colors.surface.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Row(
              children: [
                Icon(
                  a.type == AnniversaryType.countUp
                      ? Icons.favorite
                      : Icons.cake,
                  size: 13,
                  color: ownerColors[a.ownerUid] != null
                      ? Color(ownerColors[a.ownerUid]!)
                      : colors.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  '${a.title} ${dDayLabel(a, now)}',
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
