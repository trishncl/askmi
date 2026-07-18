import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// One row of the "Fast Moving Products" list: rank chip, name, quantity,
/// and a status badge. Staggers in based on [index].
class FastMovingTile extends StatelessWidget {
  final int rank;
  final String name;
  final int quantity;
  final int index;

  /// Threshold for the "Fast Moving" badge — anything at or above this
  /// many units sold in the period counts as fast moving.
  static const fastMovingThreshold = 6;

  const FastMovingTile({
    super.key,
    required this.rank,
    required this.name,
    required this.quantity,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final isFast = quantity >= fastMovingThreshold;
    final badgeColor = isFast ? AppColors.teal : const Color(0xFF3B82F6);
    final badgeTint =
        isFast ? AppColors.lightSuccess : const Color(0xFF3B82F6).withValues(alpha: 0.10);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + index * 90),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset((1 - t) * 16, 0), child: child),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.lightSuccess,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$rank',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.teal,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
            ),
            Text(
              '$quantity',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(width: 10),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: badgeTint,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isFast ? 'Fast Moving' : 'Normal',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: badgeColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}