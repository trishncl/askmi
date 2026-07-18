import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Colour-coded payment method chip. Colours are semantic per method so the
/// eye can scan a list without reading every label.
class PaymentBadge extends StatelessWidget {
  final String method;
  final double fontSize;

  const PaymentBadge({super.key, required this.method, this.fontSize = 10});

  static (Color, Color) colorsFor(String method) {
    switch (method.toLowerCase()) {
      case 'gcash':
        return (const Color(0xFF3B82F6), const Color(0xFF3B82F6));
      case 'card':
        return (AppColors.gold, AppColors.gold);
      case 'cash':
      default:
        return (AppColors.teal, AppColors.teal);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (fg, base) = colorsFor(method);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: fontSize, vertical: fontSize * 0.35),
      decoration: BoxDecoration(
        color: base.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        method.isEmpty ? 'Cash' : method,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}