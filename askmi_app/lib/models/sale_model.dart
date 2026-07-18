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
      product: d['product'] ?? '',
      quantity: (d['quantity'] ?? 0) as int,
      unitPrice: (d['unitPrice'] ?? 0).toDouble(),
      amount: (d['amount'] ?? 0).toDouble(),
      paymentMethod: d['paymentMethod'] ?? 'Cash',
      branch: d['branch'] ?? '',
      cashierUid: d['cashierUid'] ?? '',
      cashierName: d['cashierName'] ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
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