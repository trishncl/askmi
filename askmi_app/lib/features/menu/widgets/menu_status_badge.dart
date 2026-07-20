import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/menu_item_model.dart';

/// Same pill shape as StockStatusBadge (Inventory) / AvailabilityBadge
/// (Products) — status reads consistently everywhere in the app.
class MenuStatusBadge extends StatelessWidget {
  final MenuItemStatus status;
  final double fontSize;

  const MenuStatusBadge({super.key, required this.status, this.fontSize = 11});

  static (Color, String, IconData) _meta(MenuItemStatus status) {
    return switch (status) {
      MenuItemStatus.available => (AppColors.teal, 'Available', Icons.check_circle_outline_rounded),
      MenuItemStatus.hidden => (AppColors.textGray, 'Hidden', Icons.visibility_off_rounded),
      MenuItemStatus.outOfStock => (
          AppColors.danger,
          'Out of Stock',
          Icons.remove_shopping_cart_rounded,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final (color, label, icon) = _meta(status);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: fontSize * 0.9, vertical: fontSize * 0.35),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: fontSize + 1, color: color),
          SizedBox(width: fontSize * 0.4),
          Text(label, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}