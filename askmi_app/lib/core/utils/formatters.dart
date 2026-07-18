import 'package:intl/intl.dart';

/// Shared formatting helpers so currency/date styling stays identical
/// across Dashboard, Sales, and every later module.
class Fmt {
  Fmt._();

  static final peso = NumberFormat.currency(symbol: '₱', decimalDigits: 2);
  static final pesoCompact = NumberFormat.compactCurrency(symbol: '₱', decimalDigits: 0);
  static final dateTime = DateFormat('MMM d, yyyy, hh:mm a');
  static final dateOnly = DateFormat('MMM d, yyyy');
  static final timeOnly = DateFormat('hh:mm a');

  /// Human-facing reference derived from the Firestore document ID.
  ///
  /// NOT a sequential counter: Firestore IDs are random, so "TXN-K3BX" is
  /// stable and unique but has no ordering meaning. Truly sequential
  /// numbering (TXN-001, TXN-002...) needs a dedicated counter document
  /// updated in a transaction on every sale — worth doing if the business
  /// needs it for receipts/audits, but it adds a write and a contention
  /// point to every checkout.
  static String txnRef(String docId) {
    if (docId.isEmpty) return 'TXN-—';
    final tail = docId.length <= 4 ? docId : docId.substring(docId.length - 4);
    return 'TXN-${tail.toUpperCase()}';
  }
}