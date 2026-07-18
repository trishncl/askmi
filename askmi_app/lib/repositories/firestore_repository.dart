import 'package:cloud_firestore/cloud_firestore.dart';

abstract class FirestoreRepository<T> {
  final String collectionPath;
  final FirebaseFirestore _db;

  FirestoreRepository(this.collectionPath, {FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get collection => _db.collection(collectionPath);

  T fromDoc(DocumentSnapshot<Map<String, dynamic>> doc);
  Map<String, dynamic> toMap(T item);

   Stream<List<T>> watchAll({
    String? branch,
    String? orderByField,
    bool descending = true,
    int? limit,
  }) {
    Query<Map<String, dynamic>> query = collection;
    if (branch != null && branch != 'All Branches') {
      query = query.where('branch', isEqualTo: branch);
    }
    if (orderByField != null) {
      query = query.orderBy(orderByField, descending: descending);
    }
    // Pagination: rather than cursor-based paging, the Sales list grows this
    // limit as you scroll. Slightly more reads than a cursor, but it keeps
    // ONE live stream — so edits and deletes stay real-time across the whole
    // loaded range instead of only the newest page.
    if (limit != null) {
      query = query.limit(limit);
    }
    return query.snapshots().map((snap) => snap.docs.map(fromDoc).toList());
  }

  Future<List<T>> fetchAll({String? branch}) async {
    Query<Map<String, dynamic>> query = collection;
    if (branch != null && branch != 'All Branches') {
      query = query.where('branch', isEqualTo: branch);
    }
    final snap = await query.get();
    return snap.docs.map(fromDoc).toList();
  }

  Future<String> add(T item) async {
    final ref = await collection.add(toMap(item));
    return ref.id;
  }

  Future<void> setWithId(String id, T item) => collection.doc(id).set(toMap(item));

  Future<void> update(String id, T item) => collection.doc(id).update(toMap(item));

  Future<void> delete(String id) => collection.doc(id).delete();
}