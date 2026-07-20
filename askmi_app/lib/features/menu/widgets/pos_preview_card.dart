import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';

/// Renders a menu item exactly the way the cashier POS grid will show it
/// — a self-contained tile so this stays truthful even before the POS
/// screen itself exists (Phase 5). If the POS tile styling ever changes,
/// update it here and both places move together automatically, since the
/// real POS is expected to reuse this same widget rather than reimplement it.
class PosPreviewCard extends StatelessWidget {
  final String name;
  final String category;
  final double price;
  final String image;
  final bool outOfStock;

  const PosPreviewCard({
    super.key,
    required this.name,
    required this.category,
    required this.price,
    this.image = '',
    this.outOfStock = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Opacity(
        opacity: outOfStock ? 0.55 : 1,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: AspectRatio(
                  aspectRatio: 1.3,
                  child: image.trim().isEmpty
                      ? Container(
                          color: AppColors.lightSuccess,
                          alignment: Alignment.center,
                          child: const Icon(Icons.restaurant_rounded,
                              size: 32, color: AppColors.teal),
                        )
                      : Image.network(
                          image,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: AppColors.lightSuccess,
                            alignment: Alignment.center,
                            child: const Icon(Icons.restaurant_rounded,
                                size: 32, color: AppColors.teal),
                          ),
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: AppColors.textGray,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      name.isEmpty ? 'Menu item name' : name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      outOfStock ? 'Out of Stock' : Fmt.peso.format(price),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: outOfStock ? AppColors.danger : AppColors.teal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}