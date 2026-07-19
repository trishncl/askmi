import 'package:cloud_firestore/cloud_firestore.dart';

abstract class FirestoreRepository<T> {
  final String collectionPath;
  final FirebaseFirestore _db;

  FirestoreRepository(this.collectionPath, {FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;
  
  FirebaseFirestore get db => _db;

  CollectionReference<Map<String, dynamic>> get collection => _db.collection(collectionPath);

  T fromDoc(DocumentSnapshot<Map<String, dynamic>> doc);
  Map<String, dynamic> toMap(T item);

   Stream<List<T>> watchAll({
      String? branch,
      String? orderByField,
      bool descending = true,
      int? limit,
    }) {
      final filterBranch = branch != null && branch != 'All Branches';
      Query<Map<String, dynamic>> query = collection;
      if (filterBranch) {
        query = query.where('branch', isEqualTo: branch);
      }
      // Combining where + orderBy needs a composite Firestore index.
      // When branch-filtered, skip server orderBy and sort client-side instead.
      if (orderByField != null && !filterBranch) {
        query = query.orderBy(orderByField, descending: descending);
      }
      if (limit != null && !filterBranch) {
        query = query.limit(limit);
      }
      return query.snapshots().map((snap) {
        var docs = snap.docs.toList();
        if (orderByField != null && filterBranch) {
          docs.sort((a, b) {
            final av = a.data()[orderByField];
            final bv = b.data()[orderByField];
            final cmp = _compareFirestoreValues(av, bv);
            return descending ? -cmp : cmp;
          });
          if (limit != null && docs.length > limit) {
            docs = docs.take(limit).toList();
          }
        }
        return docs.map(fromDoc).toList();
      });
    }
    int _compareFirestoreValues(dynamic a, dynamic b) {
      if (a == null && b == null) return 0;
      if (a == null) return -1;
      if (b == null) return 1;
      if (a is Timestamp && b is Timestamp) {
        return a.compareTo(b);
      }
      if (a is num && b is num) return a.compareTo(b);
      if (a is String && b is String) return a.compareTo(b);
      if (a is DateTime && b is DateTime) return a.compareTo(b);
      return a.toString().compareTo(b.toString());
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