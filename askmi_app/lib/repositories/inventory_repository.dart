// inventory_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/firestore_collections.dart';
import '../models/inventory_model.dart';
import 'firestore_repository.dart';

class InventoryRepository extends FirestoreRepository<InventoryModel> {
  InventoryRepository({super.db}) : super(FirestoreCollections.inventory);

  @override
  InventoryModel fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) => InventoryModel.fromDoc(doc);

  @override
  Map<String, dynamic> toMap(InventoryModel item) => item.toMap();
}