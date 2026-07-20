import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/menu_item_model.dart';
import 'menu_status_badge.dart';

enum MenuCardAction { edit, hideToggle, duplicate, delete }

/// One menu item as a Material 3 card. The image carries a Hero tag so
/// "View Details" morphs it into the details page's header image.
class MenuItemCard extends StatelessWidget {
  final MenuItemModel item;
  final int index;
  final VoidCallback onTap; // View Details
  final bool canEdit;
  final bool canDelete;
  final ValueChanged<MenuCardAction> onAction;

  const MenuItemCard({
    super.key,
    required this.item,
    required this.index,
    required this.onTap,
    required this.canEdit,
    required this.canDelete,
    required this.onAction,
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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Thumbnail(item: item, size: 64),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: AppColors.textDark,
                              ),
                            ),
                          ),
                          if (canEdit || canDelete) _menuButton(),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.category,
                        style: const TextStyle(fontSize: 12, color: AppColors.textGray),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        Fmt.peso.format(item.price),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: AppColors.teal,
                        ),
                      ),
                      const SizedBox(height: 8),
                      MenuStatusBadge(status: item.status, fontSize: 10.5),
                    ],
                  ),
                ),
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

  Widget _menuButton() {
    return PopupMenuButton<MenuCardAction>(
      tooltip: 'More',
      icon: const Icon(Icons.more_vert_rounded, size: 20, color: AppColors.textGray),
      onSelected: onAction,
      itemBuilder: (context) => [
        if (canEdit)
          const PopupMenuItem(
            value: MenuCardAction.edit,
            child: Row(children: [
              Icon(Icons.edit_outlined, size: 18, color: AppColors.teal),
              SizedBox(width: 10),
              Text('Edit'),
            ]),
          ),
        if (canEdit)
          PopupMenuItem(
            value: MenuCardAction.hideToggle,
            child: Row(children: [
              Icon(
                item.active ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 18,
                color: AppColors.textGray,
              ),
              const SizedBox(width: 10),
              Text(item.active ? 'Hide' : 'Unhide'),
            ]),
          ),
        if (canEdit)
          const PopupMenuItem(
            value: MenuCardAction.duplicate,
            child: Row(children: [
              Icon(Icons.copy_all_outlined, size: 18, color: AppColors.textGray),
              SizedBox(width: 10),
              Text('Duplicate'),
            ]),
          ),
        if (canDelete)
          const PopupMenuItem(
            value: MenuCardAction.delete,
            child: Row(children: [
              Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.danger),
              SizedBox(width: 10),
              Text('Delete', style: TextStyle(color: AppColors.danger)),
            ]),
          ),
      ],
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final MenuItemModel item;
  final double size;
  const _Thumbnail({required this.item, required this.size});

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: 'menu_image_${item.id}',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: item.image.trim().isEmpty
            ? _placeholder()
            : Image.network(
                item.image,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholder(),
              ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: size,
      height: size,
      color: AppColors.lightSuccess,
      alignment: Alignment.center,
      child: const Icon(Icons.restaurant_rounded, color: AppColors.teal, size: 26),
    );
  }
}