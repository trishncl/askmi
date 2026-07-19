import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore collection: `sales`
class SaleModel {
  final String id;
  final String product;
  final int quantity;
  final double unitPrice;
  final double amount;
  final String paymentMethod; // 'Cash' | 'GCash'
  final String branch;
  final String cashierUid;
  final String cashierName;
  final DateTime createdAt;

  SaleModel({
    required this.id,
    required this.product,
    required this.quantity,
    required this.unitPrice,
    required this.amount,
    required this.paymentMethod,
    required this.branch,
    required this.cashierUid,
    required this.cashierName,
    required this.createdAt,
  });

  factory SaleModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return SaleModel(
      id: doc.id,
      product: _asString(d['product']),
      quantity: ((d['quantity'] ?? 0) as num).toInt(),
      unitPrice: (d['unitPrice'] ?? 0).toDouble(),
      amount: (d['amount'] ?? 0).toDouble(),
      paymentMethod: _asString(d['paymentMethod'], 'Cash'),
      branch: _asString(d['branch']),
      cashierUid: _asString(d['cashierUid']),
      cashierName: _asString(d['cashierName']),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// A field that should be a plain String but was accidentally saved as
  /// something else in Firestore (most commonly a Reference — easy to do
  /// by hand in the console, since it picks "reference" as a field type)
  /// used to crash the ENTIRE stream for every document, not just the bad
  /// one. This degrades gracefully instead: a Reference contributes its
  /// document ID, anything else falls back to its string form.
  static String _asString(dynamic value, [String fallback = '']) {
    if (value == null) return fallback;
    if (value is String) return value;
    if (value is DocumentReference) return value.id;
    return value.toString();
  }

  Map<String, dynamic> toMap() => {
        'product': product,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'amount': amount,
        'paymentMethod': paymentMethod,
        'branch': branch,
        'cashierUid': cashierUid,
        'cashierName': cashierName,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}