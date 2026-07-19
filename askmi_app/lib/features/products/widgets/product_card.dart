import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/product_model.dart';
import 'product_badges.dart';

/// One product as a Material 3 card. The avatar carries a Hero tag so
/// tapping "View Details" morphs it into the details page's header image
/// instead of a hard cut — the one Hero transition the spec calls for.
class ProductCard extends StatelessWidget {
  final ProductModel product;
  final int index;
  final VoidCallback onTap; // View Details
  final VoidCallback? onEdit; // null hides the action (Cashier: view-only)
  final Future<void> Function()? onToggleStatus; // null hides the action

  const ProductCard({
    super.key,
    required this.product,
    required this.index,
    required this.onTap,
    this.onEdit,
    this.onToggleStatus,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Avatar(product: product, size: 52),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${product.category} • ${product.branch}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: AppColors.textGray),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            Fmt.peso.format(product.price),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: AppColors.teal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    AvailabilityBadge(product: product),
                    MovementBadge(product: product),
                    Text(
                      'Stock: ${product.stock}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textGray,
                      ),
                    ),
                  ],
                ),
                if (onEdit != null || onToggleStatus != null) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (onEdit != null)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: onEdit,
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            label: const Text('Edit'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.teal,
                              side: const BorderSide(color: AppColors.border),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      if (onEdit != null && onToggleStatus != null) const SizedBox(width: 10),
                      if (onToggleStatus != null)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => onToggleStatus!(),
                            icon: Icon(
                              product.isDisabled
                                  ? Icons.power_settings_new_rounded
                                  : Icons.block_rounded,
                              size: 16,
                            ),
                            label: Text(product.isDisabled ? 'Enable' : 'Disable'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor:
                                  product.isDisabled ? AppColors.teal : AppColors.danger,
                              side: const BorderSide(color: AppColors.border),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 240 + (index.clamp(0, 8)) * 45),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * 12), child: child),
      ),
      child: card,
    );
  }
}

/// Image (if `product.image` is set) or a teal-tinted initial circle,
/// wrapped in a Hero so it can morph into the details page's larger
/// version of the same avatar.
class _Avatar extends StatelessWidget {
  final ProductModel product;
  final double size;
  const _Avatar({required this.product, required this.size});

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: 'product_avatar_${product.id}',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: product.image.trim().isEmpty
            ? _initial()
            : Image.network(
                product.image,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _initial(),
                loadingBuilder: (context, child, progress) =>
                    progress == null ? child : _initial(),
              ),
      ),
    );
  }

  Widget _initial() {
    return Container(
      width: size,
      height: size,
      color: AppColors.lightSuccess,
      alignment: Alignment.center,
      child: Text(
        product.name.isNotEmpty ? product.name[0].toUpperCase() : '?',
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 20,
          color: AppColors.teal,
        ),
      ),
    );
  }
}