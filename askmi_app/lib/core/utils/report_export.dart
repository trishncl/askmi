// ignore_for_file: duplicate_ignore, prefer_const_constructors

import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'export_file_saver.dart';
import 'formatters.dart';

/// Shared CSV + PDF export used by every Reports tab (Sales, Inventory,
/// Products, Branch Performance). Kept in one place so every export looks
/// and behaves the same rather than four slightly-different copies.
class ReportExporter {
  ReportExporter._();

  static Future<void> exportCsv({
    required BuildContext context,
    required String fileNamePrefix,
    required List<String> headers,
    required List<List<String>> rows,
    required String shareText,
  }) async {
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing to export for the current filters.')),
      );
      return;
    }

    try {
      final data = <List<String>>[headers, ...rows];
      final csv = const ListToCsvConverter().convert(data);
      await saveAndShareBytes(
        fileName: '${fileNamePrefix}_export.csv',
        bytes: utf8.encode(csv),
        mimeType: 'text/csv;charset=utf-8',
        shareText: shareText,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('CSV export failed: $e')));
      }
    }
  }

  /// [kpiSummary] and the table are rendered on every PDF export — logo,
  /// title, branch, date range, and generated-date go in the header.
  static Future<void> exportPdf({
    required BuildContext context,
    required String fileNamePrefix,
    required String reportTitle,
    required String branchLabel,
    required String dateRangeLabel,
    required List<MapEntry<String, String>> kpiSummary,
    required List<String> tableHeaders,
    required List<List<String>> tableRows,
    String? shareText,
  }) async {
    if (tableRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing to export for the current filters.')),
      );
      return;
    }

    try {
      pw.MemoryImage? logoImage;
      try {
        final logoBytes = await rootBundle.load('assets/images/logo.png');
        logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
      } catch (_) {
        // Logo is a nice-to-have — the PDF still generates without it.
      }

      final regularFont = pw.Font.ttf(await rootBundle.load('assets/fonts/segoeui.ttf'));
      final boldFont = pw.Font.ttf(await rootBundle.load('assets/fonts/segoeuib.ttf'));

      final generatedAt = Fmt.dateTime.format(DateTime.now());
      final doc = pw.Document();

      doc.addPage(
        pw.MultiPage(
          theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
          margin: const pw.EdgeInsets.all(28),
          header: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  if (logoImage != null) ...[
                    pw.SizedBox(width: 34, height: 34, child: pw.Image(logoImage)),
                    pw.SizedBox(width: 10),
                  ],
                  pw.Text(
                    'AskMi — $reportTitle',
                    // ignore: prefer_const_constructors
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Text('Branch: $branchLabel', style: const pw.TextStyle(fontSize: 10)),
              pw.Text('Date Range: $dateRangeLabel', style: const pw.TextStyle(fontSize: 10)),
              pw.Text(
                'Generated: $generatedAt',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
              ),
              pw.SizedBox(height: 10),
              pw.Divider(color: PdfColors.grey400),
            ],
          ),
          build: (ctx) => [
            pw.Text('Summary', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: const {0: pw.FlexColumnWidth(2), 1: pw.FlexColumnWidth(2)},
              children: [
                for (final entry in kpiSummary)
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(entry.key, style: const pw.TextStyle(fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          entry.value,
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Text('Records', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    for (final h in tableHeaders)
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(h, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                      ),
                  ],
                ),
                for (final row in tableRows)
                  pw.TableRow(
                    children: [
                      for (final cell in row)
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(cell, style: const pw.TextStyle(fontSize: 8.5)),
                        ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      );

      final bytes = await doc.save();
      await saveAndShareBytes(
        fileName: '${fileNamePrefix}_report.pdf',
        bytes: bytes,
        mimeType: 'application/pdf',
        shareText: shareText ?? 'AskMi — $reportTitle',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF export failed: $e')));
      }
    }
  }
}