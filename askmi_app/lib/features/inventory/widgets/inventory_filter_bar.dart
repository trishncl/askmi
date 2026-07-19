import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../inventory_filters.dart';

/// Horizontally scrolling category chips: All, Perishable, Non-Perishable,
/// Low Stock, Critical, Recently Updated. Single-select, so tapping a chip
/// just swaps [InventoryQuery.category] directly — no sheet needed for a
/// fixed list this short.
class InventoryFilterBar extends StatelessWidget {
  final InventoryQuery query;
  final ValueChanged<InventoryQuery> onChanged;

  const InventoryFilterBar({super.key, required this.query, required this.onChanged});

  static const _iconFor = {
    CategoryFilter.all: Icons.apps_rounded,
    CategoryFilter.perishable: Icons.eco_outlined,
    CategoryFilter.nonPerishable: Icons.category_outlined,
    CategoryFilter.lowStock: Icons.trending_down_rounded,
    CategoryFilter.critical: Icons.warning_amber_rounded,
    CategoryFilter.recentlyUpdated: Icons.update_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final c in CategoryFilter.values) ...[
            _chip(
              label: c.label,
              icon: _iconFor[c]!,
              selected: query.category == c,
              danger: c == CategoryFilter.critical,
              onTap: () => onChanged(query.copyWith(category: c)),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _chip({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    final accent = danger && selected ? AppColors.danger : AppColors.teal;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: selected ? accent.withValues(alpha: 0.12) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? accent : AppColors.border,
          width: selected ? 1.4 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 15, color: selected ? accent : AppColors.textGray),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: selected ? accent : AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
