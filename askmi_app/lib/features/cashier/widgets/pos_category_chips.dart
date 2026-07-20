import 'package:flutter/material.dart';
import '../../../core/constants/menu_category_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/menu_category_model.dart';

const String kPosAllCategories = 'All';

/// Horizontal scrollable row of category chips — same visual language as
/// MenuFilterBar's category row in Menu Management (features/menu/widgets/
/// menu_filter_bar.dart), kept as its own small widget here since the POS
/// grid doesn't need that bar's status/sort controls.
class PosCategoryChips extends StatelessWidget {
  final List<MenuCategoryModel> categories;
  final String selected;
  final ValueChanged<String> onSelected;

  const PosCategoryChips({
    super.key,
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _chip(
            label: kPosAllCategories,
            icon: Icons.apps_rounded,
            isSelected: selected == kPosAllCategories,
            onTap: () => onSelected(kPosAllCategories),
          ),
          const SizedBox(width: 8),
          for (final c in categories) ...[
            _chip(
              label: c.name,
              icon: iconForKey(c.iconKey),
              isSelected: selected == c.name,
              onTap: () => onSelected(c.name),
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
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: isSelected ? AppColors.teal.withValues(alpha: 0.12) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? AppColors.teal : AppColors.border,
          width: isSelected ? 1.4 : 1,
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
                Icon(icon, size: 14, color: isSelected ? AppColors.teal : AppColors.textGray),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected ? AppColors.teal : AppColors.textDark,
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
