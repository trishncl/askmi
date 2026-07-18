import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/sale_model.dart';
import 'payment_badge.dart';

/// One transaction as a card. Swipe LEFT to delete (with confirmation),
/// swipe RIGHT to open details, tap to open details with a Hero transition.
class TransactionCard extends StatelessWidget {
  final SaleModel sale;
  final int index;
  final VoidCallback onTap;
  final Future<bool> Function()? onDelete;

  const TransactionCard({
    super.key,
    required this.sale,
    required this.index,
    required this.onTap,
    this.onDelete,
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
                          Text(
                            Fmt.txnRef(sale.id),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: AppColors.textDark,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            sale.product,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textGray,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Hero tag must be unique per card AND match the
                        // details page, hence the doc id in the tag.
                        Hero(
                          tag: 'txn_amount_${sale.id}',
                          child: Material(
                            color: Colors.transparent,
                            child: Text(
                              Fmt.peso.format(sale.amount),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                                color: AppColors.teal,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        PaymentBadge(method: sale.paymentMethod),
                      ],
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right_rounded,
                        color: AppColors.textGray, size: 20),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: [
                    _meta(Icons.storefront_rounded, sale.branch),
                    _meta(Icons.person_outline_rounded,
                        sale.cashierName.isEmpty ? 'Unknown' : sale.cashierName),
                    _meta(Icons.schedule_rounded, Fmt.dateTime.format(sale.createdAt)),
                  ],
                ),
              ],
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

    if (onDelete == null) return animated;

    return Dismissible(
      key: ValueKey('txn_${sale.id}'),
      background: _swipeBg(
        alignment: Alignment.centerLeft,
        color: AppColors.lightSuccess,
        iconColor: AppColors.teal,
        icon: Icons.visibility_outlined,
        label: 'Details',
      ),
      secondaryBackground: _swipeBg(
        alignment: Alignment.centerRight,
        color: AppColors.lightDanger,
        iconColor: AppColors.danger,
        icon: Icons.delete_outline_rounded,
        label: 'Delete',
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onTap();
          return false; // swipe-right navigates, never removes the row
        }
        return onDelete!();
      },
      child: animated,
    );
  }

  Widget _meta(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.textGray),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 11.5, color: AppColors.textGray)),
      ],
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