import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/menu_item_model.dart';
import 'widgets/menu_status_badge.dart';
import 'widgets/pos_preview_card.dart';

/// Full record for one menu item, reached via a Hero transition from the
/// list. Includes a POS Preview so an Owner/Manager can confirm exactly
/// what the cashier will see before it goes live.
class MenuDetailsPage extends StatelessWidget {
  final MenuItemModel item;
  final bool canEdit;
  final bool canDelete;
  final VoidCallback? onEdit;
  final Future<void> Function()? onHideToggle;
  final Future<void> Function()? onDuplicate;
  final Future<void> Function()? onDelete;

  const MenuDetailsPage({
    super.key,
    required this.item,
    required this.canEdit,
    required this.canDelete,
    this.onEdit,
    this.onHideToggle,
    this.onDuplicate,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Menu Details'),
        actions: [
          if (canEdit)
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined),
              onPressed: onEdit,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Center(
            child: Hero(
              tag: 'menu_image_${item.id}',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: item.image.trim().isEmpty
                    ? Container(
                        width: 140,
                        height: 140,
                        color: AppColors.lightSuccess,
                        alignment: Alignment.center,
                        child: const Icon(Icons.restaurant_rounded, size: 48, color: AppColors.teal),
                      )
                    : Image.network(
                        item.image,
                        width: 140,
                        height: 140,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 140,
                          height: 140,
                          color: AppColors.lightSuccess,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: Text(
              item.name,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: AppColors.textDark),
            ),
          ),
          const SizedBox(height: 6),
          Center(child: MenuStatusBadge(status: item.status)),
          if (item.description.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              item.description.trim(),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textGray, height: 1.5),
            ),
          ],
          const SizedBox(height: 20),
          const Text('Item Information',
              style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textDark)),
          const SizedBox(height: 10),
          _infoCard([
            _row('Category', item.category),
            _row('Selling Price', Fmt.peso.format(item.price)),
            _row('Branch Availability', item.branches.isEmpty ? '—' : item.branches.join(', ')),
            _row('Status', switch (item.status) {
              MenuItemStatus.available => 'Available',
              MenuItemStatus.hidden => 'Hidden',
              MenuItemStatus.outOfStock => 'Out of Stock',
            }),
            _row('Created', Fmt.dateOnly.format(item.createdAt)),
            _row('Last Updated', Fmt.dateOnly.format(item.updatedAt)),
          ]),
          const SizedBox(height: 24),
          const Text('POS Preview',
              style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textDark)),
          const SizedBox(height: 4),
          const Text(
            'Exactly how this appears to the cashier.',
            style: TextStyle(fontSize: 12, color: AppColors.textGray),
          ),
          const SizedBox(height: 10),
          PosPreviewCard(
            name: item.name,
            category: item.category,
            price: item.price,
            image: item.image,
            outOfStock: item.outOfStock,
          ),
          if (canEdit || canDelete) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                if (canEdit)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Edit'),
                    ),
                  ),
                if (canEdit) const SizedBox(width: 10),
                if (canEdit)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onHideToggle == null ? null : () => onHideToggle!(),
                      icon: Icon(item.active ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          size: 18),
                      label: Text(item.active ? 'Hide' : 'Unhide'),
                    ),
                  ),
              ],
            ),
            if (canEdit) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onDuplicate == null ? null : () => onDuplicate!(),
                  icon: const Icon(Icons.copy_all_outlined, size: 18),
                  label: const Text('Duplicate'),
                ),
              ),
            ],
            if (canDelete) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                  ),
                  onPressed: onDelete == null ? null : () => onDelete!(),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Delete'),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _infoCard(List<Widget> rows) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: rows),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textGray)),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark),
            ),
          ),
        ],
      ),
    );
  }
}