import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/sale_model.dart';
import 'widgets/payment_badge.dart';

/// Full record for one transaction, reached via a Hero transition from the
/// list.
///
/// SCHEMA NOTE: the design brief asked for a multi-item receipt (Purchased
/// Items, Subtotal, Discount, Tax, Change). The `sales` schema stores ONE
/// product per document — a sale IS a line item — so this shows the single
/// item truthfully rather than inventing a fake basket. Multi-item receipts
/// would need an `items` array or a subcollection on each sale, plus a
/// matching change to the POS in Phase 5.
class TransactionDetailsPage extends StatelessWidget {
  final SaleModel sale;
  final VoidCallback? onEdit;

  const TransactionDetailsPage({super.key, required this.sale, this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Transaction Details'),
        actions: [
          if (onEdit != null)
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.teal, Color(0xFF1F8377)],
              ),
            ),
            child: Column(
              children: [
                Text(
                  Fmt.txnRef(sale.id),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Hero(
                  tag: 'txn_amount_${sale.id}',
                  child: Material(
                    color: Colors.transparent,
                    child: Text(
                      Fmt.peso.format(sale.amount),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                PaymentBadge(method: sale.paymentMethod, fontSize: 12),
              ],
            ),
          ),
          const SizedBox(height: 18),

          _card(
            title: 'Transaction Information',
            icon: Icons.info_outline_rounded,
            children: [
              _row('Reference', Fmt.txnRef(sale.id)),
              _row('Date', Fmt.dateOnly.format(sale.createdAt)),
              _row('Time', Fmt.timeOnly.format(sale.createdAt)),
              _row('Branch', sale.branch),
              _row('Cashier', sale.cashierName.isEmpty ? 'Unknown' : sale.cashierName),
              _row('Payment Method', sale.paymentMethod),
            ],
          ),
          const SizedBox(height: 16),

          _card(
            title: 'Purchased Item',
            icon: Icons.receipt_long_rounded,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                        color: AppColors.lightSuccess,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.lunch_dining_rounded,
                          color: AppColors.teal, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sale.product,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${sale.quantity} × ${Fmt.peso.format(sale.unitPrice)}',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textGray),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      Fmt.peso.format(sale.amount),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _card(
            title: 'Order Summary',
            icon: Icons.calculate_outlined,
            children: [
              _row('Subtotal', Fmt.peso.format(sale.amount)),
              // Discount/tax/change aren't in the schema. Showing them as
              // hardcoded zeros would look like real data; the note is
              // honest about why they're absent.
              const SizedBox(height: 4),
              const Text(
                'Discounts, tax, and change are not tracked in the current '
                'sales schema.',
                style: TextStyle(fontSize: 11.5, color: AppColors.textGray, height: 1.35),
              ),
              const Divider(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Grand Total',
                    style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textDark),
                  ),
                  Text(
                    Fmt.peso.format(sale.amount),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: AppColors.teal,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => _notImplemented(context, 'Printing'),
                  icon: const Icon(Icons.print_outlined, size: 18),
                  label: const Text('Print'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => _notImplemented(context, 'Receipt sharing'),
                  icon: const Icon(Icons.ios_share_rounded, size: 18),
                  label: const Text('Share'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _notImplemented(BuildContext context, String what) {
    // Printing needs a physical thermal-printer integration (ESC/POS over
    // Bluetooth), which is its own project — better an honest message than
    // a button that silently does nothing.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$what needs a printer integration — not built yet.')),
    );
  }

  Widget _card({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.teal),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
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
          Text(label, style: const TextStyle(color: AppColors.textGray, fontSize: 13)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}