import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';

/// One branch's summary row in the Branch Performance comparison. Only
/// the leading icon avatar carries the Hero tag (matching the pattern
/// used by ProductCard/StockItemCard) so the transition animates a small,
/// well-defined element rather than the whole row.
class BranchPerformanceCard extends StatelessWidget {
  final String branch;
  final double revenue;
  final int transactions;
  final int lowStockCount;
  final bool isTopBranch;
  final VoidCallback onTap;
  final int index;

  const BranchPerformanceCard({
    super.key,
    required this.branch,
    required this.revenue,
    required this.transactions,
    required this.lowStockCount,
    required this.isTopBranch,
    required this.onTap,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 280 + (index.clamp(0, 6)) * 60),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * 16), child: child),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                Hero(
                  tag: 'branch_perf_$branch',
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: isTopBranch ? AppColors.lightWarning : AppColors.lightSuccess,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      isTopBranch ? Icons.emoji_events_rounded : Icons.storefront_rounded,
                      color: isTopBranch ? AppColors.gold : AppColors.teal,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        branch,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textDark),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$transactions transactions • $lowStockCount low-stock',
                        style: const TextStyle(fontSize: 11.5, color: AppColors.textGray),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      Fmt.peso.format(revenue),
                      style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.teal, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    const Icon(Icons.chevron_right_rounded, color: AppColors.textGray, size: 18),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}