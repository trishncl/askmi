import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/utils/export_file_saver.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/sale_transaction_model.dart';

/// Renders a [SaleTransactionModel] to a one-page PDF and hands it to the
/// OS share sheet — the "Share Receipt" action. Reuses the same font/logo
/// loading approach as ReportExporter.exportPdf (core/utils/report_export.dart)
/// so a receipt looks like it belongs to the same app as the Reports
/// exports, without pulling the Reports feature's KPI-table-shaped API in.
class ReceiptExporter {
  ReceiptExporter._();

  static Future<void> shareReceipt(BuildContext context, SaleTransactionModel sale) async {
    try {
      pw.MemoryImage? logoImage;
      try {
        final logoBytes = await rootBundle.load('assets/images/logo.png');
        logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
      } catch (_) {
        // Logo is a nice-to-have — the receipt still generates without it.
      }

      final regularFont = pw.Font.ttf(await rootBundle.load('assets/fonts/segoeui.ttf'));
      final boldFont = pw.Font.ttf(await rootBundle.load('assets/fonts/segoeuib.ttf'));

      final doc = pw.Document();
      doc.addPage(
        pw.Page(
          theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
          pageFormat: PdfPageFormat.roll80, // thermal-receipt-width proportions
          margin: const pw.EdgeInsets.all(16),
          build: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (logoImage != null)
                pw.Center(child: pw.SizedBox(width: 40, height: 40, child: pw.Image(logoImage))),
              pw.SizedBox(height: 6),
              pw.Center(
                child: pw.Text('AskMi', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              ),
              pw.Center(child: pw.Text(sale.branch, style: const pw.TextStyle(fontSize: 9))),
              pw.SizedBox(height: 10),
              pw.Divider(color: PdfColors.grey400),
              _kv('Transaction ID', sale.transactionNumber),
              _kv('Cashier', sale.cashierName),
              _kv('Date & Time', Fmt.dateTime.format(sale.createdAt)),
              pw.Divider(color: PdfColors.grey400),
              for (final item in sale.items) ...[
                pw.Text(item.name, style: const pw.TextStyle(fontSize: 9)),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('${item.quantity} x ${Fmt.peso.format(item.unitPrice)}',
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                    pw.Text(Fmt.peso.format(item.subtotal),
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.SizedBox(height: 4),
              ],
              pw.Divider(color: PdfColors.grey400),
              _kv('Subtotal', Fmt.peso.format(sale.subtotal)),
              _kv('Payment Method', sale.paymentMethod),
              if (sale.paymentMethod == PosPaymentMethod.cash) ...[
                _kv('Cash Received', Fmt.peso.format(sale.cashReceived)),
                _kv('Change', Fmt.peso.format(sale.change)),
              ],
              pw.Divider(color: PdfColors.grey400),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  pw.Text(Fmt.peso.format(sale.total),
                      style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Center(
                child: pw.Text('Thank you!', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
              ),
            ],
          ),
        ),
      );

      final bytes = await doc.save();
      await saveAndShareBytes(
        fileName: '${sale.transactionNumber}_receipt.pdf',
        bytes: bytes,
        mimeType: 'application/pdf',
        shareText: 'AskMi Receipt — ${sale.transactionNumber}',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not share receipt: $e')));
      }
    }
  }

  static pw.Widget _kv(String k, String v) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(k, style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
            pw.Text(v, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
          ],
        ),
      );
}
