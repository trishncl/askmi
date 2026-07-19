import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../core/constants/firestore_collections.dart';
import '../models/user_model.dart';
import '../models/user_activity_model.dart';
import 'firestore_repository.dart';

class UsersRepository extends FirestoreRepository<UserModel> {
  UsersRepository({super.db}) : super(FirestoreCollections.users);

  @override
  UserModel fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) => UserModel.fromDoc(doc);

  @override
  Map<String, dynamic> toMap(UserModel item) => item.toMap();

  Future<UserModel?> fetchByUid(String uid) async {
    final doc = await collection.doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromDoc(doc);
  }

  Stream<UserModel?> watchByUid(String uid) {
    return collection.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      try {
        return UserModel.fromDoc(doc);
      } catch (e, st) {
        debugPrint('Bad user doc $uid: $e\n$st');
        return null;
      }
    });
  }

  Stream<List<UserModel>> watchUsers({String? branch}) {
    Query<Map<String, dynamic>> query = collection;
    if (branch != null && branch != 'All Branches') {
      query = query.where('branch', isEqualTo: branch);
    }
    return query.snapshots().map((snapshot) {
      final users = <UserModel>[];
      for (final doc in snapshot.docs) {
        try {
          users.add(UserModel.fromDoc(doc));
        } catch (e, st) {
          debugPrint('Skipping bad user doc ${doc.id}: $e\n$st');
        }
      }
      users.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return users;
    });
  }

  Future<bool> isUsernameTaken(String username, {String? excludeUid}) async {
    final trimmed = username.trim();
    if (trimmed.isEmpty) return false;
    final snap = await collection.where('username', isEqualTo: trimmed).limit(5).get();
    return snap.docs.any((d) => d.id != excludeUid);
  }

  Future<bool> isEmailTaken(String email, {String? excludeUid}) async {
    final trimmed = email.trim().toLowerCase();
    if (trimmed.isEmpty) return false;
    final snap = await collection.where('email', isEqualTo: trimmed).limit(5).get();
    return snap.docs.any((d) => d.id != excludeUid);
  }

  Stream<List<UserActivityModel>> watchActivity({String? targetUid}) {
    Query<Map<String, dynamic>> query =
        FirebaseFirestore.instance.collection(FirestoreCollections.userActivity);
    if (targetUid != null) {
      query = query.where('target_uid', isEqualTo: targetUid);
    }
    return query.limit(100).snapshots().map((snapshot) {
      final activity = snapshot.docs.map(UserActivityModel.fromDoc).toList();
      activity.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return activity;
    });
  }
}