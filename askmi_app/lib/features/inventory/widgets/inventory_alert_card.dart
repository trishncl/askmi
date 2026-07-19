import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/inventory_model.dart';

/// Compact banner listing critical/low-stock ingredients by name, shown
/// above the list so the most urgent items don't require scrolling to spot.
/// Tapping it jumps straight to the Critical filter.
class InventoryAlertCard extends StatelessWidget {
  final List<InventoryModel> criticalItems;
  final VoidCallback onTap;

  const InventoryAlertCard({super.key, required this.criticalItems, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (criticalItems.isEmpty) return const SizedBox.shrink();

    final names = criticalItems.map((e) => e.itemName).toList();
    final preview = names.take(3).join(', ');
    final more = names.length > 3 ? ' +${names.length - 3} more' : '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Material(
        color: AppColors.lightDanger,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${criticalItems.length} item${criticalItems.length == 1 ? '' : 's'} need attention',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$preview$more',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5, color: AppColors.textGray),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.danger, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}