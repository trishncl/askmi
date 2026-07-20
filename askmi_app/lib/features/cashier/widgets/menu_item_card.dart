import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/menu_item_model.dart';

/// Single tappable menu tile for the POS grid.
///
/// Visually matches PosPreviewCard (Menu Management's "how this will look
/// in the POS" mockup — features/menu/widgets/pos_preview_card.dart) so the
/// preview stays truthful, but this is the real thing: tappable to add to
/// cart, with a live quantity badge and a disabled Out of Stock treatment
/// instead of a static preview.
class CashierMenuItemCard extends StatelessWidget {
  final MenuItemModel item;
  final int quantityInCart;
  final VoidCallback? onTap;

  const CashierMenuItemCard({
    super.key,
    required this.item,
    this.quantityInCart = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final outOfStock = item.outOfStock;
    final inCart = quantityInCart > 0;

    return Opacity(
      opacity: outOfStock ? 0.55 : 1,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: inCart ? AppColors.teal : AppColors.border,
            width: inCart ? 1.6 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: outOfStock ? null : onTap,
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      child: AspectRatio(
                        aspectRatio: 1.3,
                        child: item.image.trim().isEmpty
                            ? Container(
                                color: AppColors.lightSuccess,
                                alignment: Alignment.center,
                                child: const Icon(Icons.restaurant_rounded,
                                    size: 32, color: AppColors.teal),
                              )
                            : Image.network(
                                item.image,
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
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.category.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: AppColors.textGray,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            outOfStock ? 'Out of Stock' : Fmt.peso.format(item.price),
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                              color: outOfStock ? AppColors.danger : AppColors.teal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (outOfStock)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.danger,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Out of Stock',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                if (inCart)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppColors.teal,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$quantityInCart',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
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
