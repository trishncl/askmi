import 'package:cloud_firestore/cloud_firestore.dart';

class UserActivityModel {
  final String id;
  final String action;
  final String targetUid;
  final String targetName;
  final String administratorUid;
  final String administratorName;
  final String branch;
  final String notes;
  final DateTime createdAt;

  const UserActivityModel({
    required this.id,
    required this.action,
    required this.targetUid,
    required this.targetName,
    required this.administratorUid,
    required this.administratorName,
    required this.branch,
    required this.notes,
    required this.createdAt,
  });

  factory UserActivityModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return UserActivityModel(
      id: doc.id,
      action: (d['action'] ?? '') as String,
      targetUid: (d['target_uid'] ?? '') as String,
      targetName: (d['target_name'] ?? '') as String,
      administratorUid: (d['administrator_uid'] ?? '') as String,
      administratorName: (d['administrator_name'] ?? '') as String,
      branch: (d['branch'] ?? '') as String,
      notes: (d['notes'] ?? '') as String,
      createdAt: (d['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}