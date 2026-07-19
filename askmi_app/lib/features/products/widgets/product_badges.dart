import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/product_model.dart';

/// Small colour-coded pill, shared shape for both badge kinds on a
/// product card — same visual language as StockStatusBadge (Inventory)
/// and PaymentBadge (Sales) so status reads consistently app-wide.
class _Pill extends StatelessWidget {
  final Color color;
  final String label;
  final IconData? icon;

  const _Pill({required this.color, required this.label, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

/// Availability badge: Available / Low Stock / Out of Stock / Disabled.
/// Reads [ProductModel.badgeStatus] — never recomputes the logic here, so
/// the list, the details page, and the card all agree by construction.
class AvailabilityBadge extends StatelessWidget {
  final ProductModel product;
  const AvailabilityBadge({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return switch (product.badgeStatus) {
      ProductBadgeStatus.available => const _Pill(color: AppColors.teal, label: 'Available'),
      ProductBadgeStatus.lowStock =>
        const _Pill(color: AppColors.gold, label: 'Low Stock', icon: Icons.trending_down_rounded),
      ProductBadgeStatus.outOfStock => const _Pill(
          color: AppColors.danger, label: 'Out of Stock', icon: Icons.remove_shopping_cart_rounded),
      ProductBadgeStatus.disabled =>
        const _Pill(color: AppColors.textGray, label: 'Disabled', icon: Icons.block_rounded),
    };
  }
}

/// Movement badge: Fast Moving / Normal. Purely a display of the stored
/// `movement_status` field — set by a human on the form, never inferred
/// from sales velocity here (that's explicitly out of scope).
class MovementBadge extends StatelessWidget {
  final ProductModel product;
  const MovementBadge({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return product.isFastMoving
        ? const _Pill(color: Color(0xFF3B82F6), label: 'Fast Moving', icon: Icons.bolt_rounded)
        : const _Pill(color: AppColors.textGray, label: 'Normal');
  }
}