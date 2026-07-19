import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/firestore_collections.dart';
import '../models/report_model.dart';
import 'firestore_repository.dart';

class ReportsRepository extends FirestoreRepository<ReportModel> {
  ReportsRepository({super.db}) : super(FirestoreCollections.reports);

  @override
  ReportModel fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) => ReportModel.fromDoc(doc);

  @override
  Map<String, dynamic> toMap(ReportModel item) => item.toMap();

  Future<void> markReviewed(String id) => collection.doc(id).update({'reviewed': true});

  /// A Manager's own submission history — base `watchAll` only filters by
  /// `branch`, not by who sent it, so this needs its own query.
  Stream<List<ReportModel>> watchBySender(String uid) {
    return collection
        .where('senderUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(fromDoc).toList());
  }
}