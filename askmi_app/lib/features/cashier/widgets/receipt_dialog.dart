import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/sale_transaction_model.dart';
import 'receipt_exporter.dart';
import 'receipt_view.dart';

/// Shown immediately after a successful checkout. Confirms the sale went
/// through, then presents the full receipt with Print (future-ready — see
/// note below) and Share actions, matching the pattern the existing
/// Owner/Manager transaction details page already established
/// (features/sales/transaction_details_page.dart).
Future<void> showReceiptDialog(BuildContext context, SaleTransactionModel sale) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => ReceiptDialog(sale: sale),
  );
}

class ReceiptDialog extends StatelessWidget {
  final SaleTransactionModel sale;
  const ReceiptDialog({super.key, required this.sale});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: AppColors.lightSuccess,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_circle_rounded, color: AppColors.teal, size: 26),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Sale Complete',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.textDark),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ReceiptView(sale: sale),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () => _printNotImplemented(context),
                        icon: const Icon(Icons.print_outlined, size: 18),
                        label: const Text('Print'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () => ReceiptExporter.shareReceipt(context, sale),
                        icon: const Icon(Icons.ios_share_rounded, size: 18),
                        label: const Text('Share'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _printNotImplemented(BuildContext context) {
    // Same honest stance as the Owner/Manager transaction details page:
    // thermal-printer output (ESC/POS over Bluetooth/USB) is real hardware
    // integration work, not something to fake with a dead button. Sharing
    // the PDF above already covers "get this receipt onto another device
    // or print queue" in the meantime.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Printing needs a receipt-printer integration — not built yet.')),
    );
  }
}
