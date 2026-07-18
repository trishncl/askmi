// branches_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/firestore_collections.dart';
import '../models/branch_model.dart';
import 'firestore_repository.dart';

class BranchesRepository extends FirestoreRepository<BranchModel> {
  BranchesRepository({super.db}) : super(FirestoreCollections.branches);

  @override
  BranchModel fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) => BranchModel.fromDoc(doc);

  @override
  Map<String, dynamic> toMap(BranchModel item) => item.toMap();
}