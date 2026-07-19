import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/inventory_model.dart';
import 'stock_status_badge.dart';

/// One inventory record as a mobile card. Swipe RIGHT opens edit, swipe
/// LEFT deletes (with confirmation) — mirrors TransactionCard's dismiss
/// pattern but with edit/delete swapped, per the Inventory spec (Sales
/// uses swipe-right for details since transactions aren't edited inline).
///
/// Edit/delete (icons + swipe) only show for roles allowed to mutate
/// (Owner/Manager). Staff/Cashier get a plain view-only card — tapping it
/// still opens details, so there's no separate "view" icon duplicating that.
class StockItemCard extends StatelessWidget {
  final InventoryModel item;
  final int index;
  final bool canMutate;
  final VoidCallback onTap; // View Details
  final VoidCallback? onEdit;
  final Future<bool> Function()? onDelete;

  const StockItemCard({
    super.key,
    required this.item,
    required this.index,
    required this.canMutate,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });

  bool get _isPerishable => item.category.toLowerCase() == 'perishable';

  @override
  Widget build(BuildContext context) {
    final card = Hero(
      tag: 'inventory_${item.id}',
      child: Container(
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
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    item.itemName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _categoryPill(),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                const Icon(Icons.storefront_rounded, size: 12, color: AppColors.textGray),
                                const SizedBox(width: 4),
                                Text(
                                  item.branch,
                                  style: const TextStyle(fontSize: 11.5, color: AppColors.textGray),
                                ),
                                const Text(' • ', style: TextStyle(color: AppColors.textGray)),
                                Text(
                                  Fmt.dateOnly.format(item.date),
                                  style: const TextStyle(fontSize: 11.5, color: AppColors.textGray),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      StockStatusBadge(status: item.status),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _metric('Opening', item.opening, item.unit)),
                      Expanded(child: _metric('Deliveries', item.deliveries, item.unit)),
                      Expanded(child: _metric('Closing', item.closing, item.unit)),
                      Expanded(
                        child: _metric(
                          'Wastage',
                          item.wastage, item.unit,
                          valueColor: item.wastage > 0 ? AppColors.danger : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.lightSuccess,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calculate_outlined, size: 15, color: AppColors.teal),
                        const SizedBox(width: 8),
                        const Text(
                          'Estimated Consumption: ',
                          style: TextStyle(fontSize: 12, color: AppColors.textDark),
                        ),
                        Text(
                          '${_fmtNum(item.estimatedConsumption)} ${item.unit}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.teal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (item.notes.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      '"${item.notes.trim()}"',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: AppColors.textGray,
                      ),
                    ),
                  ],
                  if (canMutate && (onEdit != null || onDelete != null)) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (onEdit != null)
                          _iconAction(
                            icon: Icons.edit_outlined,
                            color: AppColors.teal,
                            tooltip: 'Edit',
                            onTap: onEdit!,
                          ),
                        if (onEdit != null && onDelete != null) const SizedBox(width: 6),
                        if (onDelete != null)
                          _iconAction(
                            icon: Icons.delete_outline_rounded,
                            color: AppColors.danger,
                            tooltip: 'Delete',
                            onTap: () => onDelete!(),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final animated = TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 260 + (index.clamp(0, 8)) * 55),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * 14), child: child),
      ),
      child: card,
    );

    if (!canMutate || (onEdit == null && onDelete == null)) {
      return animated;
    }

    return Dismissible(
      key: ValueKey('inv_${item.id}'),
      background: onEdit == null
          ? null
          : _swipeBg(
              alignment: Alignment.centerLeft,
              color: AppColors.lightSuccess,
              iconColor: AppColors.teal,
              icon: Icons.edit_outlined,
              label: 'Edit',
            ),
      secondaryBackground: onDelete == null
          ? null
          : _swipeBg(
              alignment: Alignment.centerRight,
              color: AppColors.lightDanger,
              iconColor: AppColors.danger,
              icon: Icons.delete_outline_rounded,
              label: 'Delete',
            ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          if (onEdit == null) return false;
          onEdit!();
          return false; // swipe-right opens the editor, never removes the row
        }
        if (onDelete == null) return false;
        return onDelete!();
      },
      child: animated,
    );
  }

  Widget _categoryPill() {
    final color = _isPerishable ? AppColors.gold : const Color(0xFF3B82F6);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        item.category,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  Widget _metric(String label, double value, String unit, {Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10.5, color: AppColors.textGray)),
        const SizedBox(height: 2),
        Text(
          '${_fmtNum(value)} $unit',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: valueColor ?? AppColors.textDark,
          ),
        ),
      ],
    );
  }

  static String _fmtNum(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  Widget _iconAction({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, size: 17, color: color),
          ),
        ),
      ),
    );
  }

  Widget _swipeBg({
    required Alignment alignment,
    required Color color,
    required Color iconColor,
    required IconData icon,
    required String label,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(18)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: iconColor, fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ],
      ),
    );
  }
}