// products_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/firestore_collections.dart';
import '../models/product_model.dart';
import 'firestore_repository.dart';

class ProductsRepository extends FirestoreRepository<ProductModel> {
  ProductsRepository({super.db}) : super(FirestoreCollections.products);

  @override
  ProductModel fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) => ProductModel.fromDoc(doc);

  @override
  Map<String, dynamic> toMap(ProductModel item) => item.toMap();

  /// Client-side existence check ahead of a write — the Spark plan here has
  /// no Cloud Functions, so there's no server-side trigger to enforce
  /// uniqueness; this is the same "check then write" approach the rest of
  /// the app uses instead. Matches case-insensitively and trims, so
  /// "Buko Juice " and "buko juice" both collide with "Buko Juice".
  /// [excludeId] lets an edit save without tripping over itself.
  Future<bool> nameExistsInBranch(String name, String branch, {String? excludeId}) async {
    final normalized = name.trim().toLowerCase();
    if (normalized.isEmpty) return false;

    final snap = await collection.where('branch', isEqualTo: branch).get();
    return snap.docs.any((doc) {
      if (doc.id == excludeId) return false;
      final docName = (doc.data()['name'] as String? ?? '').trim().toLowerCase();
      return docName == normalized;
    });
  }

  /// Toggle-only status flip for the Enable/Disable action — a narrower
  /// write than a full `update()` so a quick list-screen tap can't
  /// accidentally clobber fields it never read (price, stock, etc).
  Future<void> setStatus(String id, String status) =>
      collection.doc(id).update({'status': status, 'updatedAt': Timestamp.now()});

  /// Called after a completed sale. Never lets stock go negative — a sale
  /// larger than remaining stock clamps to 0 rather than erroring, since
  /// blocking the whole checkout over a stock-count mismatch is worse than
  /// briefly showing 0.
  Future<void> decrementStock(String id, int by) async {
    final doc = collection.doc(id);
    await db.runTransaction((tx) async {
      final snap = await tx.get(doc);
      final current = ((snap.data()?['stock'] ?? 0) as num).toInt();
      final next = (current - by) < 0 ? 0 : current - by;
      tx.update(doc, {'stock': next, 'updatedAt': Timestamp.now()});
    });
  }
}