// sales_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/firestore_collections.dart';
import '../models/sale_model.dart';
import 'firestore_repository.dart';

class SalesRepository extends FirestoreRepository<SaleModel> {
  SalesRepository({super.db}) : super(FirestoreCollections.sales);

  @override
  SaleModel fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) => SaleModel.fromDoc(doc);

  @override
  Map<String, dynamic> toMap(SaleModel item) => item.toMap();

  /// Live feed of one product's transactions in one branch — powers Product
  /// Details' "units sold today/this week" and transaction count. Two
  /// equality filters only (no orderBy alongside them), so this doesn't
  /// need a composite index; date-bucketing happens client-side instead.
  /// [limit] bounds reads for a product with a very long sales history —
  /// stats become "recent" rather than all-time once a product exceeds it.
  Stream<List<SaleModel>> watchByProduct(String productName, String branch, {int limit = 500}) {
    return collection
        .where('branch', isEqualTo: branch)
        .where('product', isEqualTo: productName)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(fromDoc).toList());
  }

  Future<bool> hasAnySalesFor(String productName) async {
    final snap = await collection.where('product', isEqualTo: productName).limit(1).get();
    return snap.docs.isNotEmpty;
  }
}