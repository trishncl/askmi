import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/sale_model.dart';

/// One row of "Recent Transactions". Swipe left to archive or delete.
///
/// NOTE: archive/delete are wired to callbacks but the Dashboard passes
/// no-op handlers for now — mutating sales belongs to the Sales sprint,
/// where validation and Firestore rules for writes get built and tested
/// together.
class TransactionTile extends StatelessWidget {
  final SaleModel sale;
  final int index;
  final VoidCallback? onTap;
  final Future<bool> Function()? onArchive;
  final Future<bool> Function()? onDelete;

  const TransactionTile({
    super.key,
    required this.sale,
    required this.index,
    this.onTap,
    this.onArchive,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isGCash = sale.paymentMethod.toLowerCase() == 'gcash';
    final badgeColor = isGCash ? const Color(0xFF3B82F6) : AppColors.teal;
    final badgeTint = isGCash
        ? const Color(0xFF3B82F6).withValues(alpha: 0.10)
        : AppColors.lightSuccess;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + index * 80),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(opacity: t, child: child),
      child: Dismissible(
        key: ValueKey(sale.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 18),
          decoration: BoxDecoration(
            color: AppColors.lightWarning,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.archive_outlined, color: AppColors.warning),
        ),
        confirmDismiss: (_) async {
          if (onArchive != null) return onArchive!();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Archiving arrives with the Sales sprint.')),
          );
          return false;
        },
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sale.product.isEmpty ? 'Transaction' : sale.product,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${sale.branch} • ${DateFormat('hh:mm a').format(sale.createdAt)}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textGray),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      NumberFormat.currency(symbol: '₱', decimalDigits: 2)
                          .format(sale.amount),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: badgeTint,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        sale.paymentMethod,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: badgeColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}