import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/sale_transaction_model.dart';

/// Itemized receipt content — Transaction ID, branch, cashier, line items,
/// payment method, total, and change. Rendered inside [ReceiptDialog]
/// right after checkout, and again (read-only) inside
/// PosTransactionDetailsPage from Sales History, so a cashier sees the
/// exact same layout whether it's a fresh sale or something they're
/// looking back up.
class ReceiptView extends StatelessWidget {
  final SaleTransactionModel sale;

  const ReceiptView({super.key, required this.sale});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _headerRow('Transaction ID', sale.transactionNumber, emphasize: true),
        const SizedBox(height: 6),
        _headerRow('Branch', sale.branch),
        const SizedBox(height: 6),
        _headerRow('Cashier', sale.cashierName),
        const SizedBox(height: 6),
        _headerRow('Date & Time', Fmt.dateTime.format(sale.createdAt)),
        const SizedBox(height: 16),
        const Divider(height: 1, color: AppColors.border),
        const SizedBox(height: 12),
        const Text(
          'Items',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.textDark),
        ),
        const SizedBox(height: 8),
        for (final item in sale.items) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    item.name,
                    style: const TextStyle(fontSize: 13, color: AppColors.textDark),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    '${item.quantity} × ${Fmt.peso.format(item.unitPrice)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: AppColors.textGray),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    Fmt.peso.format(item.subtotal),
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        const Divider(height: 1, color: AppColors.border),
        const SizedBox(height: 12),
        _summaryRow('Subtotal', Fmt.peso.format(sale.subtotal)),
        const SizedBox(height: 6),
        _summaryRow('Payment Method', sale.paymentMethod),
        if (sale.paymentMethod == PosPaymentMethod.cash) ...[
          const SizedBox(height: 6),
          _summaryRow('Cash Received', Fmt.peso.format(sale.cashReceived)),
          const SizedBox(height: 6),
          _summaryRow('Change', Fmt.peso.format(sale.change)),
        ],
        const SizedBox(height: 12),
        const Divider(height: 1, color: AppColors.border),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Total',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textDark),
            ),
            Text(
              Fmt.peso.format(sale.total),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: AppColors.teal),
            ),
          ],
        ),
      ],
    );
  }

  Widget _headerRow(String label, String value, {bool emphasize = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.textGray)),
        Text(
          value,
          style: TextStyle(
            fontSize: emphasize ? 13.5 : 12.5,
            fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
            color: emphasize ? AppColors.teal : AppColors.textDark,
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textGray)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark)),
      ],
    );
  }
}
