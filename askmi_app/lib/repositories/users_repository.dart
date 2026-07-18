import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/firestore_collections.dart';
import '../models/user_model.dart';
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
    return collection.doc(uid).snapshots().map((doc) => doc.exists ? UserModel.fromDoc(doc) : null);
  }
}