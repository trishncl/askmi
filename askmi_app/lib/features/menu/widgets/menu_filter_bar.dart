import 'package:flutter/material.dart';
import '../../../core/constants/menu_category_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/menu_category_model.dart';
import '../menu_filters.dart';

/// Two rows: category chips (dynamic, from Firestore) on top, then
/// status chips + sort button below. Categories are their own scrollable
/// row since the list can grow arbitrarily long (Category Management can
/// add more at any time) — mixing them into one row with status would
/// make status chips unreachable once there are enough categories.
class MenuFilterBar extends StatelessWidget {
  final MenuQuery query;
  final List<MenuCategoryModel> categories;
  final ValueChanged<MenuQuery> onChanged;

  const MenuFilterBar({
    super.key,
    required this.query,
    required this.categories,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _chip(
                label: kAllCategoriesFilter,
                icon: Icons.apps_rounded,
                selected: query.category == kAllCategoriesFilter,
                onTap: () => onChanged(query.copyWith(category: kAllCategoriesFilter)),
              ),
              const SizedBox(width: 8),
              for (final c in categories) ...[
                _chip(
                  label: c.name,
                  icon: iconForKey(c.iconKey),
                  selected: query.category == c.name,
                  onTap: () => onChanged(query.copyWith(category: c.name)),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: Row(
            children: [
              Expanded(
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(left: 16),
                  children: [
                    for (final s in MenuStatusFilter.values) ...[
                      _chip(
                        label: s.label,
                        selected: query.status == s,
                        onTap: () => onChanged(query.copyWith(status: s)),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 16, left: 4),
                child: _sortButton(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sortButton() {
    return PopupMenuButton<MenuSort>(
      tooltip: 'Sort',
      initialValue: query.sort,
      onSelected: (s) => onChanged(query.copyWith(sort: s)),
      itemBuilder: (context) => [
        for (final s in MenuSort.values)
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