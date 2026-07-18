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
}