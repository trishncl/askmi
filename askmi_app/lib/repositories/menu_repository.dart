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

  /// Branch-aware live query. NOT the inherited `watchAll(branch: ...)` —
  /// that helper does `where('branch', isEqualTo: ...)`, which is correct
  /// for every other collection's single-string `branch` field but silently
  /// returns nothing here, since `branch` on a menu item is a LIST (an item
  /// can serve several branches at once). This uses `arrayContains`
  /// instead, which is the correct operator for "is this branch in the
  /// item's branch list".
  ///
  /// Sorting is done client-side rather than via Firestore's `.orderBy()`.
  /// `.orderBy(field)` silently EXCLUDES any document that doesn't have
  /// that field at all — it doesn't sort it to one end, it drops it from
  /// the result set with no error. Documents created by hand in the
  /// Firestore console (or written before `displayOrder` existed in the
  /// schema) don't have `displayOrder`, so they'd quietly vanish from
  /// every query here. `MenuItemModel.fromDoc` already defaults a missing
  /// `displayOrder` to 0, so sorting client-side gives every matching
  /// document something to compare against instead of excluding it.
  Stream<List<MenuItemModel>> watchAllForBranch({
    String? branch,
    String? orderByField,
    bool descending = false,
    int? limit,
  }) {
    Query<Map<String, dynamic>> query = collection;
    if (branch != null && branch != 'All Branches') {
      query = query.where('branch', arrayContains: branch);
    }
    return query.snapshots().map((snap) {
      var docs = snap.docs.map(fromDoc).toList();
      if (orderByField == 'displayOrder') {
        docs.sort((a, b) => descending
            ? b.displayOrder.compareTo(a.displayOrder)
            : a.displayOrder.compareTo(b.displayOrder));
      }
      if (limit != null && docs.length > limit) {
        docs = docs.take(limit).toList();
      }
      return docs;
    });
  }

  /// Same reasoning as ProductsRepository.nameExistsInBranch — client-side
  /// pre-check ahead of a write, Spark plan has no Cloud Functions trigger
  /// to enforce this server-side. A menu item "in a branch" here means the
  /// branch list overlaps, since the same name could legitimately exist at
  /// two branches that never share availability... except the brief treats
  /// menu names as globally identifying the dish, so this checks ANY
  /// existing item with the same name, not just ones sharing a branch —
  /// two "Buko Juice" menu entries would otherwise be indistinguishable in
  /// search, POS Preview, and Category Management.
  Future<bool> nameExists(String name, {String? excludeId}) async {
    final normalized = name.trim().toLowerCase();
    if (normalized.isEmpty) return false;

    final snap = await collection.get();
    return snap.docs.any((doc) {
      if (doc.id == excludeId) return false;
      final docName = (doc.data()['name'] as String? ?? '').trim().toLowerCase();
      return docName == normalized;
    });
  }

  /// Hide/Unhide — a narrower write than a full `update()`.
  Future<void> setActive(String id, bool active) =>
      collection.doc(id).update({'active': active, 'updatedAt': Timestamp.now()});

  /// Duplicate: same fields, new doc, appended "(Copy)", starts Hidden so
  /// it never accidentally doubles up in the live POS before someone
  /// reviews it.
  Future<String> duplicate(MenuItemModel item) async {
    final copy = item.copyWith(
      name: '${item.name} (Copy)',
      active: false,
      updatedAt: DateTime.now(),
    );
    final ref = await collection.add({
      ...copy.toMap(),
      'createdAt': Timestamp.fromDate(DateTime.now()),
    });
    return ref.id;
  }

  /// Persists a new relative order for a set of items in one write —
  /// used by drag-and-drop reordering so a mid-drag crash can't leave the
  /// list half-renumbered.
  Future<void> saveDisplayOrder(List<MenuItemModel> orderedItems) async {
    final batch = db.batch();
    for (var i = 0; i < orderedItems.length; i++) {
      batch.update(collection.doc(orderedItems[i].id), {
        'displayOrder': i,
        'updatedAt': Timestamp.now(),
      });
    }
    await batch.commit();
  }
}