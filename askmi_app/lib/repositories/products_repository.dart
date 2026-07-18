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
}