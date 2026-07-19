import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/inventory_model.dart';

/// Colour-coded stock-health chip — same pill styling as PaymentBadge
/// (Sales) so status reads consistently across modules.
class StockStatusBadge extends StatelessWidget {
  final StockStatus status;
  final double fontSize;

  const StockStatusBadge({super.key, required this.status, this.fontSize = 10});

  static (Color, String) _meta(StockStatus status) {
    switch (status) {
      case StockStatus.healthy:
        return (AppColors.teal, 'Healthy');
      case StockStatus.low:
        return (AppColors.gold, 'Low Stock');
      case StockStatus.critical:
        return (AppColors.danger, 'Critical');
      case StockStatus.overstock:
        return (const Color(0xFF3B82F6), 'Overstock');
    }
  }

  @override
  Widget build(BuildContext context) {
    final (color, label) = _meta(status);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: fontSize * 1.1, vertical: fontSize * 0.4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: fontSize * 0.55,
            height: fontSize * 0.55,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: fontSize * 0.5),
          Text(
            label,
            style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}