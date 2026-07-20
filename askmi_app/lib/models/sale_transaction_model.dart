import 'package:cloud_firestore/cloud_firestore.dart';

/// Raw values stored in Firestore for a POS sale's `paymentMethod`. Kept as
/// plain strings (not a Dart enum) on the doc — same convention as
/// SaleModel.paymentMethod elsewhere in this app.
class PosPaymentMethod {
  PosPaymentMethod._();
  static const cash = 'Cash';
  static const gcash = 'GCash';
  static const values = [cash, gcash];
}

/// One line within a POS transaction — a menu item + quantity, with the
/// price it was actually sold at frozen onto the line. Freezing the price
/// here (rather than re-reading MenuItemModel.price at display time) means
/// a later price change in Menu Management never silently rewrites past
/// receipts.
class SaleLineItem {
  final String menuItemId;
  final String name;
  final String category;
  final double unitPrice;
  final int quantity;

  const SaleLineItem({
    required this.menuItemId,
    required this.name,
    required this.category,
    required this.unitPrice,
    required this.quantity,
  });

  double get subtotal => unitPrice * quantity;

  Map<String, dynamic> toMap() => {
        'menuItemId': menuItemId,
        'name': name,
        'category': category,
        'unitPrice': unitPrice,
        'quantity': quantity,
        'subtotal': subtotal,
      };

  factory SaleLineItem.fromMap(Map<String, dynamic> m) => SaleLineItem(
        menuItemId: (m['menuItemId'] ?? '').toString(),
        name: (m['name'] ?? '').toString(),
        category: (m['category'] ?? '').toString(),
        unitPrice: ((m['unitPrice'] ?? 0) as num).toDouble(),
        quantity: ((m['quantity'] ?? 0) as num).toInt(),
      );
}

/// Firestore collection: `sales` — written by the Cashier POS checkout,
/// ONE document per transaction (a full receipt with many line items).
///
/// This is a deliberately separate model from the existing `SaleModel` in
/// this project, which the Owner/Manager "Sales" module (sale_form_page.dart)
/// still uses for manual, single-product entries. The two shapes genuinely
/// diverge — SaleModel is line-first (one product per doc, no basket), this
/// is transaction-first (one receipt, many line items, cash tendered/change)
/// — so extending SaleModel would mean bolting an `items[]` array onto a
/// model built around a single `product` string. Both write to the same
/// `sales` collection (per the brief), tagged with `type: 'pos'` so the two
/// kinds of documents can always be told apart; the Owner/Manager Sales
/// screen and SaleModel are untouched by this module.
class SaleTransactionModel {
  final String id;
  final String transactionNumber;
  final String branch;
  final String cashierUid;
  final String cashierName;
  final List<SaleLineItem> items;
  final double subtotal;
  final double total;
  final String paymentMethod; // PosPaymentMethod
  final double cashReceived;
  final double change;
  final DateTime createdAt;

  const SaleTransactionModel({
    required this.id,
    required this.transactionNumber,
    required this.branch,
    required this.cashierUid,
    required this.cashierName,
    required this.items,
    required this.subtotal,
    required this.total,
    required this.paymentMethod,
    required this.cashReceived,
    required this.change,
    required this.createdAt,
  });

  int get totalQuantity => items.fold(0, (sum, i) => sum + i.quantity);

  factory SaleTransactionModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    final rawItems = d['items'];
    return SaleTransactionModel(
      id: doc.id,
      transactionNumber: (d['transactionNumber'] ?? '').toString(),
      branch: (d['branch'] ?? '').toString(),
      cashierUid: (d['cashierUid'] ?? '').toString(),
      cashierName: (d['cashierName'] ?? '').toString(),
      items: rawItems is List
          ? rawItems
              .whereType<Map>()
              .map((m) => SaleLineItem.fromMap(Map<String, dynamic>.from(m)))
              .toList()
          : const [],
      subtotal: ((d['subtotal'] ?? 0) as num).toDouble(),
      total: ((d['total'] ?? 0) as num).toDouble(),
      paymentMethod: (d['paymentMethod'] ?? PosPaymentMethod.cash).toString(),
      cashReceived: ((d['cashReceived'] ?? 0) as num).toDouble(),
      change: ((d['change'] ?? 0) as num).toDouble(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        // Distinguishes this doc shape from the legacy per-product
        // SaleModel docs also living in `sales` — see class doc above.
        'type': 'pos',
        'transactionNumber': transactionNumber,
        'branch': branch,
        'cashierUid': cashierUid,
        'cashierName': cashierName,
        'items': items.map((i) => i.toMap()).toList(),
        'subtotal': subtotal,
        'total': total,
        'paymentMethod': paymentMethod,
        'cashReceived': cashReceived,
        'change': change,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
