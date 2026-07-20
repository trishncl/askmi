// menu_categories_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/firestore_collections.dart';
import '../models/menu_category_model.dart';
import 'firestore_repository.dart';

class MenuCategoriesRepository extends FirestoreRepository<MenuCategoryModel> {
  MenuCategoriesRepository({super.db}) : super(FirestoreCollections.menuCategories);

  @override
  MenuCategoryModel fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      MenuCategoryModel.fromDoc(doc);

  @override
  Map<String, dynamic> toMap(MenuCategoryModel item) => item.toMap();

  Stream<List<MenuCategoryModel>> watchAllOrdered() {
    return collection
        .orderBy('displayOrder')
        .snapshots()
        .map((snap) => snap.docs.map(fromDoc).toList());
  }

  Future<bool> nameExists(String name, {String? excludeId}) async {
    final normalized = name.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    final snap = await collection.get();
    return snap.docs.any((doc) {
      if (doc.id == excludeId) return false;
      return (doc.data()['name'] as String? ?? '').trim().toLowerCase() == normalized;
    });
  }

  /// Same one-batch-write reasoning as MenuRepository.saveDisplayOrder.
  Future<void> saveOrder(List<MenuCategoryModel> orderedCategories) async {
    final batch = db.batch();
    for (var i = 0; i < orderedCategories.length; i++) {
      batch.update(collection.doc(orderedCategories[i].id), {
        'displayOrder': i,
        'updatedAt': Timestamp.now(),
      });
    }
    await batch.commit();
  }

  /// One-time seed so a fresh project isn't an empty picker — called by
  /// the Category Management page the first time it sees zero categories.
  Future<void> seedDefaultsIfEmpty(List<(String, String, int)> defaults) async {
    final existing = await collection.limit(1).get();
    if (existing.docs.isNotEmpty) return;

    final batch = db.batch();
    for (final (name, iconKey, order) in defaults) {
      batch.set(collection.doc(), {
        'name': name,
        'iconKey': iconKey,
        'displayOrder': order,
        'updatedAt': Timestamp.now(),
      });
    }
    await batch.commit();
  }
}