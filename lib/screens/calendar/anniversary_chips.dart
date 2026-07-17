import 'package:flutter/material.dart';
import '../../models/anniversary_model.dart';
import '../../utils/dday_utils.dart';

class AnniversaryChips extends StatelessWidget {
  final List<AnniversaryModel> anniversaries;

  const AnniversaryChips({super.key, required this.anniversaries});

  @override
  Widget build(BuildContext context) {
    if (anniversaries.isEmpty) return const SizedBox.shrink();
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
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(
                  a.type == AnniversaryType.countUp
                      ? Icons.favorite
                      : Icons.cake,
                  size: 13,
                  color: Colors.white,
                ),
                const SizedBox(width: 4),
                Text(
                  '${a.title} ${dDayLabel(a, now)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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
