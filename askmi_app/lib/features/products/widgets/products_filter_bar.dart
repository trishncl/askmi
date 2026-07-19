import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../products_filters.dart';

/// Status + Movement chips in one scrollable strip, with a pinned Sort
/// button at the end. Deliberately not a dropdown for status/movement —
/// the brief calls those out as "filters" (glanceable, always visible),
/// while sort is a single hidden-until-needed choice, so a PopupMenuButton
/// fits sort better than a third chip row would.
class ProductsFilterBar extends StatelessWidget {
  final ProductsQuery query;
  final ValueChanged<ProductsQuery> onChanged;

  const ProductsFilterBar({super.key, required this.query, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 16),
              children: [
                for (final s in StatusFilter.values) ...[
                  _chip(
                    label: s.label,
                    selected: query.status == s,
                    onTap: () => onChanged(query.copyWith(status: s)),
                  ),
                  const SizedBox(width: 8),
                ],
                Container(width: 1, height: 22, color: AppColors.border),
                const SizedBox(width: 8),
                for (final m in MovementFilter.values) ...[
                  _chip(
                    label: m.label,
                    selected: query.movement == m,
                    icon: m == MovementFilter.fastMoving ? Icons.bolt_rounded : null,
                    onTap: () => onChanged(query.copyWith(movement: m)),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16, left: 4),
            child: _sortButton(context),
          ),
        ],
      ),
    );
  }

  Widget _sortButton(BuildContext context) {
    return PopupMenuButton<ProductSort>(
      tooltip: 'Sort',
      initialValue: query.sort,
      onSelected: (s) => onChanged(query.copyWith(sort: s)),
      itemBuilder: (context) => [
        for (final s in ProductSort.values)
          PopupMenuItem(
            value: s,
            child: Row(
              children: [
                if (s == query.sort)
                  const Icon(Icons.check_rounded, size: 16, color: AppColors.teal)
                else
                  const SizedBox(width: 16),
                const SizedBox(width: 8),
                Text(s.label),
              ],
            ),
          ),
      ],
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sort_rounded, size: 16, color: AppColors.teal),
            SizedBox(width: 4),
            Icon(Icons.expand_more_rounded, size: 16, color: AppColors.textGray),
          ],
        ),
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: selected ? AppColors.teal.withValues(alpha: 0.12) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? AppColors.teal : AppColors.border,
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
                if (icon != null) ...[
                  Icon(icon, size: 14, color: selected ? AppColors.teal : AppColors.textGray),
                  const SizedBox(width: 5),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: selected ? AppColors.teal : AppColors.textDark,
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