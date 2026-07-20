// pos_sales_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/firestore_collections.dart';
import '../core/utils/formatters.dart';
import '../models/sale_transaction_model.dart';
import 'firestore_repository.dart';
import 'products_repository.dart';

/// Thrown when checkout fails a business-rule check (empty cart, insufficient
/// stock, invalid payment) rather than a network/permission error — lets the
/// UI show the message straight to the cashier instead of a generic
/// "Something went wrong".
class PosCheckoutException implements Exception {
  final String message;
  PosCheckoutException(this.message);
  @override
  String toString() => message;
}

class PosSalesRepository extends FirestoreRepository<SaleTransactionModel> {
  PosSalesRepository({super.db}) : super(FirestoreCollections.sales);

  @override
  SaleTransactionModel fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      SaleTransactionModel.fromDoc(doc);

  @override
  Map<String, dynamic> toMap(SaleTransactionModel item) => item.toMap();

  /// Cashier's own Sales History — filtered to `cashierUid` only, matching
  /// the "Cashiers can view only transactions they created" permission.
  /// Two equality filters, no `orderBy` alongside them (see
  /// FirestoreRepository.watchAll's note on the same trade-off for branch
  /// filters) — sorts client-side instead of requiring a composite index.
  Stream<List<SaleTransactionModel>> watchOwnTransactions({
    required String cashierUid,
    int limit = 300,
  }) {
    return collection
        .where('cashierUid', isEqualTo: cashierUid)
        .where('type', isEqualTo: 'pos')
        .limit(limit)
        .snapshots()
        .map((snap) {
      final docs = <SaleTransactionModel>[];
      for (final doc in snap.docs) {
        try {
          docs.add(fromDoc(doc));
        } catch (_) {
          // A malformed doc shouldn't take down the whole history — same
          // defensive stance as UsersRepository.watchUsers.
        }
      }
      docs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return docs;
    });
  }

  /// Validates, writes the transaction, and updates linked product stock —
  /// all inside ONE Firestore transaction so a crash or a race between two
  /// cashiers can never leave the sale recorded without the stock move (or
  /// vice versa).
  ///
  /// The transaction re-reads every linked product's stock at commit time
  /// (not the possibly-stale value the cart was built against) and aborts
  /// the whole checkout if any line no longer has enough — the standard
  /// "read fresh, then write" pattern `runTransaction` exists for.
  Future<SaleTransactionModel> checkout({
    required String branch,
    required String cashierUid,
    required String cashierName,
    required List<SaleLineItem> items,
    required String paymentMethod,
    required double cashReceived,
  }) async {
    if (items.isEmpty) {
      throw PosCheckoutException('Your cart is empty.');
    }
    if (items.any((l) => l.quantity <= 0)) {
      throw PosCheckoutException('Every item needs a quantity of at least 1.');
    }

    final total = items.fold<double>(0, (sum, l) => sum + l.subtotal);

    if (paymentMethod == PosPaymentMethod.cash && cashReceived < total) {
      throw PosCheckoutException('Cash received is less than the total due.');
    }

    final ref = collection.doc();
    final productsRepo = ProductsRepository(db: db);

    // Resolve each line's linked product (if any) BEFORE opening the
    // transaction — `findByNameInBranch` runs its own query, and
    // Firestore transactions only allow reads via `tx.get()` on already-
    // known document references.
    final linkedProductId = <String, String>{}; // menuItemId -> product doc id
    for (final line in items) {
      final product = await productsRepo.findByNameInBranch(line.name, branch);
      if (product != null) linkedProductId[line.menuItemId] = product.id;
    }

    final sale = SaleTransactionModel(
      id: ref.id,
      // Reuses the same human-readable reference scheme every other sale
      // reference in this app already uses (Fmt.txnRef) rather than
      // inventing a second numbering convention.
      transactionNumber: Fmt.txnRef(ref.id),
      branch: branch,
      cashierUid: cashierUid,
      cashierName: cashierName,
      items: items,
      subtotal: total,
      total: total,
      paymentMethod: paymentMethod,
      cashReceived: paymentMethod == PosPaymentMethod.cash ? cashReceived : 0,
      change: paymentMethod == PosPaymentMethod.cash ? (cashReceived - total) : 0,
      createdAt: DateTime.now(),
    );

    await db.runTransaction((tx) async {
      // Firestore transactions require ALL reads before any write.
      final freshProducts = <String, DocumentSnapshot<Map<String, dynamic>>>{};
      for (final entry in linkedProductId.entries) {
        freshProducts[entry.key] = await tx.get(productsRepo.collection.doc(entry.value));
      }

      for (final line in items) {
        final snap = freshProducts[line.menuItemId];
        if (snap == null || !snap.exists) continue; // no linked stock row — nothing to validate
        final stock = ((snap.data()?['stock'] ?? 0) as num).toInt();
        if (stock < line.quantity) {
          throw PosCheckoutException('${line.name} only has $stock left in stock.');
        }
      }

      tx.set(ref, sale.toMap());

      for (final line in items) {
        final snap = freshProducts[line.menuItemId];
        if (snap == null || !snap.exists) continue;
        final data = snap.data()!;
        final stock = ((data['stock'] ?? 0) as num).toInt();
        final sold = ((data['soldStock'] ?? 0) as num).toInt();
        tx.update(snap.reference, {
          'stock': (stock - line.quantity) < 0 ? 0 : stock - line.quantity,
          'soldStock': sold + line.quantity,
          'updatedAt': Timestamp.now(),
        });
      }
    });

    return sale;
  }
}
