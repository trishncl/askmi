import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/inventory_model.dart';
import 'widgets/stock_status_badge.dart';

class InventoryDetailsPage extends StatelessWidget {
  final InventoryModel item;
  final bool canMutate;
  final VoidCallback? onEdit;
  final Future<bool> Function()? onDelete;

  const InventoryDetailsPage({
    super.key,
    required this.item,
    required this.canMutate,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Inventory Details'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Hero(
            tag: 'inventory_${item.id}',
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            color: AppColors.lightSuccess,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(Icons.inventory_2_rounded, color: AppColors.teal),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.itemName,
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${item.category} • ${item.branch}',
                                style: const TextStyle(color: AppColors.textGray),
                              ),
                            ],
                          ),
                        ),
                        StockStatusBadge(status: item.status, fontSize: 11),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _row('Date', Fmt.dateOnly.format(item.date)),
                    _row('Opening Stock', '${_n(item.opening)} ${item.unit}'),
                    _row('Deliveries', '${_n(item.deliveries)} ${item.unit}'),
                    _row('Estimated Consumption', '${_n(item.estimatedConsumption)} ${item.unit}'),
                    _row('Closing Stock', '${_n(item.closing)} ${item.unit}'),
                    _row('Wastage', '${_n(item.wastage)} ${item.unit}'),
                    if (item.notes.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Text('Notes', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('"${item.notes.trim()}"', style: const TextStyle(color: AppColors.textGray)),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Stock Movement', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                _metric('Opening to Closing', item.opening == 0 ? 0 : item.closing / item.opening),
                const SizedBox(height: 12),
                _metric('Used vs Opening', item.opening == 0 ? 0 : item.estimatedConsumption / item.opening),
                const SizedBox(height: 12),
                _metric('Wastage Share', item.opening == 0 ? 0 : item.wastage / item.opening),
              ],
            ),
          ),
          if (canMutate && (onEdit != null || onDelete != null)) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                if (onEdit != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Edit Inventory'),
                    ),
                  ),
                if (onEdit != null && onDelete != null) const SizedBox(width: 12),
                if (onDelete != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.danger),
                      ),
                      onPressed: () async {
                        final deleted = await onDelete!();
                        if (deleted && context.mounted) {
                          Navigator.pop(context);
                        }
                      },
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('Delete Log'),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Inventory history view is not tracked yet.')),
              );
            },
            icon: const Icon(Icons.timeline_rounded, size: 18),
            label: const Text('View History'),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textGray)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, double value) {
    final progress = value.clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: progress,
          minHeight: 6,
          backgroundColor: AppColors.border,
          color: AppColors.teal,
          borderRadius: BorderRadius.circular(999),
        ),
      ],
    );
  }

  static String _n(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}