// menu_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/firestore_collections.dart';
import '../models/menu_item_model.dart';
import 'firestore_repository.dart';

class MenuRepository extends FirestoreRepository<MenuItemModel> {
  MenuRepository({super.db}) : super(FirestoreCollections.menuItems);

  @override
  MenuItemModel fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) => MenuItemModel.fromDoc(doc);

  @override
  Map<String, dynamic> toMap(MenuItemModel item) => item.toMap();
}